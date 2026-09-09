defmodule DBus.Bus do
  @moduledoc """
  D-Bus Bus proxy module
  """
  use DBus.Proxy

  import Bitwise

  require Logger

  alias :dbus_pubsub, as: PubSub
  alias DBus.Bus.ServiceMonitor
  alias DBus.Connection
  alias DBus.Interfaces
  alias DBus.Message
  alias DBus.Proxy
  alias DBus.RPC

  @flag_allow_replacement 1
  @flag_replace_existing 2
  @flag_do_not_queue 4

  # RequestName reply codes, org.freedesktop.DBus spec
  @request_name_primary_owner 1
  @request_name_in_queue 2
  @request_name_exists 3
  @request_name_already_owner 4

  @type register_option ::
          :allow_replacement
          | :replace_existing
          | :do_not_queue

  defmodule State do
    @moduledoc false
    defstruct conn: nil, unique_name: nil, monitor: nil, acquired: []
  end

  @path "/org/freedesktop/DBus"
  @destination "org.freedesktop.DBus"

  @interface "org.freedesktop.DBus"
  @member_name_acquired "NameAcquired"

  @spec start_link(term, Connection.connection(), atom) :: {:ok, pid} | {:error, term}
  def start_link(init_arg, conn, ref) do
    Proxy.start_link(__MODULE__, init_arg, conn, server_ref: ref)
  end

  defdelegate rpc_call(ref, call), to: Proxy

  @spec get_name_owner(GenServer.server(), String.t()) :: {:ok, String.t()} | {:error, any()}
  def get_name_owner(ref, name) do
    call =
      Interfaces.Bus
      |> Message.method_call(@interface, "GetNameOwner")
      |> Message.path(@path)
      |> Message.destination(@destination)
      |> Message.body([name])

    Proxy.rpc_call(ref, call)
  end

  @spec has_interface?(GenServer.server(), String.t(), String.t(), String.t()) ::
          {:ok, boolean} | {:error, any()}
  def has_interface?(ref, service, path, interface) do
    Proxy.call(ref, {:has_interface, service, path, interface})
  end

  @spec unregister_service(GenServer.server(), String.t()) :: :ok | {:error, any()}
  def unregister_service(ref, name) do
    Proxy.call(ref, {:unregister_service, name})
  end

  @doc """
  Register a service on the bus:
  call NameAcquired then dispatch incoming messages to the caller once the name is acquired.

  Service will receive messages of the kind:
  `{:dbus, dbus_type(), dbus_message()}`
  """
  @spec register_service(GenServer.server(), String.t(), [register_option()]) ::
          :ok | {:error, any()}
  def register_service(proxy, name, opts \\ []) do
    Proxy.call(proxy, {:register_service, name, opts})
  end

  @impl true
  def init(conn, _args) do
    {:ok, monitor} = ServiceMonitor.start_link()

    hello =
      Interfaces.Bus
      |> Message.method_call(@interface, "Hello")
      |> Message.path(@path)
      |> Message.destination(@destination)

    case RPC.call(conn, hello) do
      {:ok, name} when is_binary(name) ->
        Logger.info("Acquired bus name #{name}")
        {:ok, %State{conn: conn, unique_name: name, monitor: monitor}}

      {:error, reason} ->
        Logger.error("Failed to acquire bus name: #{reason}")
        {:error, reason}
    end
  end

  @impl true
  def handle_dbus_method_call(message, state) do
    dispatch_message(message, state)
  end

  @impl true
  def handle_dbus_method_return(message, state) do
    dispatch_message(message, state)
  end

  @impl true
  def handle_dbus_error(message, state) do
    dispatch_message(message, state)
  end

  @impl true
  def handle_dbus_signal(message, state) do
    interface = Message.find_field(message, :interface)
    member = Message.find_field(message, :member)

    case {interface, member} do
      {@interface, @member_name_acquired} ->
        case Message.body(message) do
          ":" <> _ ->
            # Unique name, already processed when saying hello
            {:noreply, state}

          name ->
            do_subscribe_service(name, state)
            {:noreply, %{state | acquired: [name | state.acquired]}}
        end

      _ ->
        dispatch_message(message, state)
    end
  end

  @impl true
  def handle_call({:register_service, name, opts}, {service, _}, state) do
    request =
      Interfaces.Bus
      |> Message.method_call(@interface, "RequestName")
      |> Message.path(@path)
      |> Message.destination(@destination)
      |> Message.body([name, process_request_name_opts(opts, 0)])

    case RPC.call(state.conn, request) do
      {:ok, @request_name_primary_owner} ->
        {:reply, :ok, wait_for_acquire(name, service, state)}

      {:ok, @request_name_already_owner} ->
        {:reply, :ok, state}

      {:ok, @request_name_in_queue} ->
        {:reply, :ok, wait_for_acquire(name, service, state)}

      {:ok, @request_name_exists} ->
        {:reply, {:error, :exists}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:unregister_service, name}, _from, state) do
    request =
      Interfaces.Bus
      |> Message.method_call(@interface, "ReleaseName")
      |> Message.path(@path)
      |> Message.destination(@destination)
      |> Message.body([name])

    case RPC.call(state.conn, request) do
      {:ok, _} ->
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:has_interface, _service, _path, _interface}, _from, state) do
    # TBD
    result = {:ok, true}
    {:reply, result, state}
  end

  defp process_request_name_opts([], flag) do
    flag
  end

  defp process_request_name_opts([:allow_replacement | rest], flag) do
    process_request_name_opts(rest, bor(flag, @flag_allow_replacement))
  end

  defp process_request_name_opts([:replace_existing | rest], flag) do
    process_request_name_opts(rest, bor(flag, @flag_replace_existing))
  end

  defp process_request_name_opts([:do_not_queue | rest], flag) do
    process_request_name_opts(rest, bor(flag, @flag_do_not_queue))
  end

  defp process_request_name_opts([_ | rest], flag) do
    process_request_name_opts(rest, flag)
  end

  defp wait_for_acquire(name, service, state) do
    :ok = ServiceMonitor.monitor(state.monitor, name, service)
    state
  end

  defp do_subscribe_service(name, state) do
    case ServiceMonitor.get_service(state.monitor, name) do
      {:ok, service} -> PubSub.subscribe(name, service)
      :error -> :ok
    end
  end

  defp dispatch_message(message, state) do
    case Message.find_field(message, :destination) do
      nil ->
        {:noreply, state}

      destination ->
        PubSub.publish(destination, {:dbus, Message.type(message), message})
        {:noreply, state}
    end
  end
end

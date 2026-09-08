defmodule DBus.Bus do
  @moduledoc """
  D-Bus Bus proxy module
  """
  use DBus.Proxy

  require Logger

  alias DBus.Connection
  alias DBus.Message
  alias DBus.Proxy
  alias DBus.RPC

  defmodule State do
    @moduledoc false
    defstruct conn: nil, unique_name: nil, acquired: []
  end

  @path "/org/freedesktop/DBus"
  @interface "org.freedesktop.DBus"
  @destination "org.freedesktop.DBus"
  @member_hello "Hello"
  @member_name_acquired "NameAcquired"

  @spec start_link(term, Connection.connection(), atom) :: {:ok, pid} | {:error, term}
  def start_link(init_arg, conn, ref) do
    Proxy.start_link(__MODULE__, init_arg, conn, server_ref: ref)
  end

  def init(conn, _args) do
    hello =
      :dbus_method_call.build(
        @member_hello,
        @path,
        [],
        interface: @interface,
        destination: @destination
      )

    case RPC.call(conn, hello) do
      {:ok, name} when is_binary(name) ->
        Logger.info("Acquired bus name #{name}")
        {:ok, %State{conn: conn, unique_name: name}}

      {:error, reason} ->
        Logger.error("Failed to acquire bus name: #{reason}")
        {:error, reason}
    end
  end

  def handle_signal(message, state) do
    interface = Message.find_field(message, :interface)
    member = Message.find_field(message, :member)
    do_handle_signal(interface, member, message, state)
  end

  defp do_handle_signal(
         @interface,
         @member_name_acquired,
         message,
         state
       ) do
    case Message.get_body(message) do
      ":" <> _ ->
        # Unique name, already processed when saying hello
        {:noreply, state}

      name ->
        {:noreply, %{state | acquired: [name | state.acquired]}}
    end
  end

  defp do_handle_signal(_interface, _member, _message, state) do
    {:noreply, state}
  end
end

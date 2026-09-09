defmodule DBus.Service do
  @moduledoc false
  use GenServer

  alias DBus.Bus
  alias DBus.Connection
  alias DBus.DOM.Spec
  alias DBus.DOM.Tree
  alias DBus.Message
  alias DBus.Router

  @callback init(term()) :: {:ok, term()} | {:error, any()}
  @callback handle_call(term(), GenServer.from(), term()) ::
              {:reply, term(), term()} | {:error, any()}

  defmacro __using__(_opts) do
    quote do
      @behaviour DBus.Service

      def child_spec(opts) do
        service_opts = [
          name: Keyword.get(opts, :name),
          # A D-Bus address (:session, :system or an address string), resolved to
          # the `DBus.Bus` proxy at init time: child_spec/1 runs in the process
          # calling `Supervisor.start_link/2`, where the bus may not exist yet.
          bus: Keyword.fetch!(opts, :bus),
          # Schema based routing is fine for compilation time
          schema: Keyword.get(opts, :schema, __MODULE__),
          # Router based dispatching may be used for dynamic objects
          router: Keyword.get(opts, :router),
          service: __MODULE__,
          # Everything the caller passed is handed over to `c:init/1`
          ctx: opts
        ]

        %{
          id: __MODULE__,
          start: {DBus.Service, :start_link, [service_opts]},
          type: :worker,
          restart: :permanent,
          shutdown: 500
        }
      end

      @impl true
      def handle_call(_call, _from, state) do
        {:reply, :ok, state}
      end

      defoverridable handle_call: 3
    end
  end

  defmodule State do
    @moduledoc false
    defstruct name: nil,
              root: nil,
              bus: nil,
              conn: nil,
              registered_objects: nil,
              router: nil,
              service: nil,
              ctx: nil,
              error: nil
  end

  @type option ::
          {:name, String.t()}
          | {:bus, DBus.address()}
          | {:service, module()}
          | {:ctx, term()}
          | {:schema, module()}
          | {:router, any()}

  @spec start_link([option()], GenServer.options()) :: GenServer.on_start()
  def start_link(opts, gen_opts \\ []) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @spec call(GenServer.server(), term()) :: {:ok, term()} | {:error, any()}
  def call(service, request) do
    GenServer.call(service, {:call, request})
  end

  @spec get_name(GenServer.server() | {:via, atom(), any()}) :: nil | String.t()
  def get_name(service) do
    GenServer.call(service, :get_name)
  end

  @spec replace_interface(GenServer.server(), String.t(), String.t()) :: :ok | {:error, any()}
  def replace_interface(service, path, interface) do
    GenServer.call(service, {:replace_interface, path, interface})
  end

  @spec register_object(GenServer.server(), String.t()) :: {:ok, pid()} | {:error, any()}
  def register_object(service, path) do
    GenServer.call(service, {:register_object, path, service})
  end

  @spec register_object(GenServer.server(), String.t(), pid() | atom()) ::
          {:ok, pid()} | {:error, any()}
  def register_object(service, path, server)
      when is_pid(server) or is_atom(server) do
    GenServer.call(service, {:register_object, path, server})
  end

  @spec unregister_object(GenServer.server(), String.t()) :: :ok
  def unregister_object(service, path) do
    GenServer.call(service, {:unregister_object, path})
  end

  @spec object_registered?(GenServer.server(), String.t()) :: boolean()
  def object_registered?(service, path) do
    GenServer.call(service, {:is_object_registered, path})
  end

  ###
  ### Callbacks
  ###
  @impl true
  def init([_ | _] = opts) do
    service = Keyword.fetch!(opts, :service)
    service_name = Keyword.get(opts, :name)
    router = Keyword.get(opts, :router)
    address = Keyword.fetch!(opts, :bus)

    root =
      opts
      |> Keyword.fetch!(:schema)
      |> get_root()

    _ = Process.flag(:trap_exit, true)

    case DBus.get_proxy(address) do
      nil ->
        {:stop, {:no_bus, address}}

      bus ->
        do_init(bus, service, service_name, root, router, opts)
    end
  end

  defp do_init(bus, service, service_name, root, router, opts) do
    registered_objects =
      :ets.new(:registered_objects, [
        :set,
        :private
      ])

    %State{
      name: service_name,
      root: root,
      bus: bus,
      conn: Bus.get_conn(bus),
      service: service,
      ctx: Keyword.get(opts, :ctx, %{}),
      registered_objects: registered_objects,
      router: router,
      error: nil
    }
    |> do_init_service()
    |> case do
      {:ok, state} ->
        case Bus.register_service(bus, service_name) do
          :ok ->
            {:ok, state}

          {:error, :exists} ->
            {:stop, {:name_exists, service_name}}

          {:error, reason} ->
            {:stop, reason}
        end

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:call, request}, from, %State{service: service, ctx: ctx} = state) do
    case service.handle_call(request, from, ctx) do
      {:reply, reply, new_ctx} ->
        {:reply, reply, %State{state | ctx: new_ctx}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_name, _from, %{name: name} = state) do
    {:reply, name, state}
  end

  def handle_call({:get_object, path}, _from, %{root: root} = state) do
    {:reply, Tree.find_path(root, path), state}
  end

  def handle_call({:get_interface, path, name}, _from, %{root: root} = state) do
    case Tree.find_path(root, path) do
      {:ok, object} ->
        {:reply, Tree.find_interface(object, name), state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:register_object, path, pid}, _from, state) do
    case do_get_registered_object(state, path) do
      nil ->
        do_register_object(state, path, pid)

      {^pid, _} ->
        # Ignore, the object is already registered to the same pid
        {:reply, {:ok, pid}, state}

      {pid, _} ->
        {:reply, {:error, "Object path already registered #{pid}"}, state}
    end
  end

  def handle_call({:unregister_object, path}, _from, state) do
    {:reply, :ok, do_unregister_path(state, path)}
  end

  def handle_call({:is_object_registered, path}, _, state) do
    case do_get_registered_object(state, path) do
      nil ->
        {:reply, false, state}

      {_pid, _ref} ->
        # Objects pids are monitored.
        # If pid is there, object is alive
        {:reply, true, state}
    end
  end

  def handle_call({:replace_interface, path, interface}, _from, %{root: root} = state) do
    case Tree.replace_interface_at(root, path, interface) do
      {:ok, root} -> {:reply, :ok, Map.put(state, :root, root)}
      _ -> {:reply, :error, state}
    end
  end

  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(_request, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, %State{registered_objects: pid} = state) do
    {:stop, reason, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, do_unregister_pid(state, pid)}
  end

  # `DBus.Bus` publishes messages addressed to our name as {:dbus, type, message}
  def handle_info({:dbus, :method_call, msg}, %State{conn: conn} = state) do
    path = Message.find_field(msg, :path, "")

    case do_get_registered_object(state, path) do
      {pid, _ref} ->
        # Registered objects reply themselves: hand them the connection too
        send(pid, {:dbus_method_call, msg, conn})
        {:noreply, state}

      nil ->
        {:noreply, handle_dbus_method_call(msg, conn, state)}
    end
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  ###
  ### Private
  ###
  defp get_root(schema) when is_atom(schema) and not is_nil(schema) do
    Code.ensure_loaded!(schema)

    if function_exported?(schema, :__schema__, 0) do
      get_root(schema.__schema__())
    else
      raise "Invalid :schema (#{inspect(schema)}): the module must `use DBus.Schema` " <>
              "and declare a `node do ... end` block"
    end
  end

  defp get_root({:object, _, _} = root) do
    root
  end

  defp get_root(_) do
    raise "Invalid :schema provided. Must be a module or a :object tree struct"
  end

  defp do_register_object(%State{registered_objects: r} = state, path, pid) do
    # Do register
    ref = Process.monitor(pid)
    true = :ets.insert(r, {path, pid, ref})
    state
  end

  defp do_unregister_path(%State{registered_objects: r} = state, path) do
    # Do unregister
    with {_pid, ref} <- do_get_registered_object(state, path) do
      true = :ets.delete(r, path)
      Process.demonitor(ref, [:flush])
    end

    state
  end

  defp do_unregister_pid(%State{registered_objects: r} = state, pid) do
    case :ets.match_object(r, {:"$1", pid, :"$2"}) do
      [{path, ^pid, ref}] ->
        true = :ets.delete(r, path)
        Process.demonitor(ref, [:flush])

      _ ->
        :ok
    end

    state
  end

  defp do_get_registered_object(%{registered_objects: r}, path) do
    case :ets.lookup(r, path) do
      [] -> nil
      [{_path, pid, ref}] -> {pid, ref}
    end
  end

  defp handle_dbus_method_call(msg, conn, state) do
    # These go into `exec_dbus_method_call/2`, which matches them against the
    # schema, so an absent field has to arrive as "" rather than nil. `:signature`
    # is the header field, the signature as written ("su"); `Message.signature/1`
    # would return the parsed `body_sig` instead, which is not what
    # `Finder.get_method_signature/1` is compared against.
    path = Message.find_field(msg, :path, "")
    interface = Message.find_field(msg, :interface, "")
    member = Message.find_field(msg, :member, "")
    signature = Message.find_field(msg, :signature, "")
    body = Message.body(msg)

    reply =
      {path, interface, member, signature, body}
      |> exec_dbus_method_call(state)
      |> case do
        {:ok, types, values} ->
          msg
          |> Message.method_return()
          |> Message.body(types, values)

        {:error, name, message} ->
          msg
          |> Message.error(name)
          |> Message.body([:string], [message])
      end

    {:ok, _} = Connection.send(conn, reply)

    state
  end

  @spec exec_dbus_method_call(
          {path :: String.t(), interface_name :: String.t(), method_name :: String.t(),
           signature :: String.t(), body :: any},
          state :: map()
        ) ::
          Spec.dbus_reply()
  def exec_dbus_method_call(
        {path, interface_name, method_name, signature, args},
        %State{root: root} = state
      ) do
    with {:object, {:ok, object}} <- {:object, Tree.find_path([root], path)},
         {:interface, {:ok, interface}} <-
           {:interface, Tree.find_interface(object, interface_name)},
         {:method, {:ok, method}} <-
           {:method, Tree.find_method(interface, method_name, signature)} do
      case Tree.get_method_callback(method) do
        {:ok, callback} ->
          call_method_callback(
            callback,
            method_name,
            args,
            %{
              node: object,
              path: path,
              interface: interface_name,
              method: method_name,
              signature: signature,
              ctx: state.ctx
            }
          )

        nil ->
          route_method(state.router, path, interface_name, method_name, signature, args, %{
            node: object,
            router: state.router
          })

        _ ->
          {:error, "org.freedesktop.DBus.Error.UnknownMethod",
           "Method not found on given interface"}
      end
    else
      {:object, _} ->
        {:error, "org.freedesktop.DBus.Error.UnknownObject",
         "No such object (#{path}) in the service"}

      {:interface, _} ->
        {:error, "org.freedesktop.DBus.Error.UnknownInterface",
         "Interface (#{interface_name}) not found at given path"}

      {:method, _} ->
        {:error, "org.freedesktop.DBus.Error.UnknownMethod",
         "Method (#{method_name}) not found on given interface"}
    end
  end

  # The only Router.Protocol implementation shipped here is the Any fallback, which
  # always returns :skip. Dialyzer therefore sees the `result` clause below as dead,
  # although it is what every consumer-defined router goes through.
  @dialyzer {:no_match, route_method: 7}
  defp route_method(router, path, interface, method, signature, args, context) do
    Router.Protocol.method(router, path, interface, method, signature, args, context)
  rescue
    _e ->
      {:error, "org.freedesktop.DBus.Error.UnknownMethod", "Method not found on given interface"}
  else
    :skip ->
      {:error, "org.freedesktop.DBus.Error.UnknownMethod", "Method not found on given interface"}

    result ->
      result
  end

  defp call_method_callback(callback, _method_name, args, context) when is_function(callback) do
    callback.(args, context)
  rescue
    e ->
      {:error, "org.freedesktop.DBus.Error.Failed", Exception.message(e)}
  else
    return -> return
  end

  defp do_init_service(%State{service: service, ctx: ctx} = state) do
    case service.init(ctx) do
      {:ok, new_ctx} ->
        {:ok, %State{state | ctx: new_ctx}}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    error ->
      {:error, Exception.message(error)}
  end
end

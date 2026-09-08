defmodule DBus.Proxy do
  @moduledoc """
  D-Bus proxy behaviour for modules proxying a remote D-Bus object
  """
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour :dbus_proxy

      if not Module.has_attribute?(__MODULE__, :doc) do
        @doc """
        Returns a specification to start this module under a supervisor.

        See `Supervisor`.
        """
      end

      def child_spec([init_arg, conn, server_opts]) do
        default = %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [init_arg, conn, server_opts]}
        }

        Supervisor.child_spec(default, unquote(Macro.escape(opts)))
      end

      defoverridable child_spec: 1

      def handle_dbus_method_call(_message, state) do
        {:noreply, state}
      end

      def handle_dbus_method_return(_message, state) do
        {:noreply, state}
      end

      def handle_dbus_signal(_message, state) do
        {:noreply, state}
      end

      def handle_dbus_error(_message, state) do
        {:noreply, state}
      end

      def handle_call(_call, _from, state) do
        {:noreply, state}
      end

      defoverridable handle_dbus_method_call: 2,
                     handle_dbus_method_return: 2,
                     handle_dbus_signal: 2,
                     handle_dbus_error: 2,
                     handle_call: 3
    end
  end

  defdelegate start_link(mod, init_args, conn, opts), to: :dbus_proxy

  defdelegate call(proxy, request), to: :dbus_proxy

  defdelegate call(proxy, request, timeout), to: :dbus_proxy

  defdelegate rpc_call(proxy, call), to: :dbus_proxy

  defdelegate rpc_call(proxy, call, timeout), to: :dbus_proxy

  defdelegate stop(proxy), to: :dbus_proxy
end

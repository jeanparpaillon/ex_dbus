defmodule ExDBus do
  @moduledoc """
  This module holds the D-Bus proxy.

  Connection to a D-Bus bus is the main application entry point for interacting
  with the bus.
  """
  alias :dbus_address, as: Address
  alias :dbus_bus, as: Bus
  alias :dbus_connection, as: Connection

  # Bus address, for instance from DBUS_SYSTEM_BUS env var
  @type address() ::
          :system
          | :session
          | binary()

  @spec start_link(address(), [Connection.option()]) :: Supervisor.on_start()
  def start_link(address, conn_opts \\ []) do
    sup_ref = sup_ref(address)
    conn_ref = conn_ref(address)
    proxy_ref = proxy_ref(address)

    address
    |> resolve_address()
    |> Address.parse()
    |> case do
      {:ok, addresses} ->
        connection_args = [
          addresses,
          [{:server_ref, {:local, conn_ref}}]
        ]

        proxy_args = [conn_ref, {:local, proxy_ref}]

        children = [
          %{
            id: :dbus_connection,
            start: {Connection, :start_link, connection_args}
          },
          %{
            id: :dbus_bus,
            start: {Bus, :start_link, proxy_args}
          }
        ]

        Supervisor.start_link(children, strategy: :rest_for_one, name: sup_ref)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec get_conn(address()) :: GenServer.server() | nil
  def get_conn(address) do
    address |> get_children(:dbus_connection)
  end

  @spec get_proxy(address()) :: GenServer.server() | nil
  def get_proxy(address) do
    address |> get_children(:dbus_bus)
  end

  @spec stop(address()) :: :ok
  def stop(address) do
    Supervisor.stop(sup_ref(address))
  end

  #
  # Priv
  #
  defp base_name(:system), do: "dbus_system"
  defp base_name(:session), do: "dbus_session"
  defp base_name(address) when is_binary(address), do: address

  defp sup_ref(address), do: :"#{base_name(address)}_sup"

  defp proxy_ref(address), do: :"#{base_name(address)}_proxy"

  defp conn_ref(address), do: :"#{base_name(address)}_conn"

  defp resolve_address(:system) do
    # As of https://dbus.freedesktop.org/doc/dbus-specification.html#message-bus-overview
    # If the environment variable is not set, fall back to the default system bus socket.
    System.get_env("DBUS_SYSTEM_BUS_ADDRESS", "unix:path=/var/run/dbus/system_bus_socket")
  end

  defp resolve_address(:session) do
    case System.get_env("DBUS_SESSION_BUS_ADDRESS") do
      nil ->
        {:ok, uid} = :dbus_auth.detect_uid()
        "unix:path=/run/user/#{uid}/bus"

      addr ->
        addr
    end
  end

  defp resolve_address(address) when is_binary(address) do
    address
  end

  @spec get_children(address(), atom()) ::
          nil
          | :restarting
          | pid()
  defp get_children(address, id) do
    address
    |> sup_ref()
    |> Supervisor.which_children()
    |> Enum.find(fn
      {^id, child, _type, _module} -> child
      _ -> nil
    end)
  catch
    :exit, _reason ->
      nil
  end
end

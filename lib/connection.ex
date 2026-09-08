defmodule DBus.Connection do
  @moduledoc """
  Elixir facility that delegates to :dbus_connection
  """

  @type connection :: GenServer.on_start()

  def child_spec(opts) do
    %{
      id: DBus.Connection,
      start: {DBus.Connection, :start_link, opts}
    }
  end

  defdelegate start_link(addresses), to: :dbus_connection

  defdelegate start_link(addresses, options), to: :dbus_connection

  defdelegate stop(conn), to: :dbus_connection

  defdelegate get_guid(conn), to: :dbus_connection

  defdelegate subscribe(conn), to: :dbus_connection

  defdelegate send(conn, message), to: :dbus_connection
end

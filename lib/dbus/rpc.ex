defmodule DBus.RPC do
  @moduledoc """
  Elixir facility that delegates to :dbus_rpc for making remote procedure calls over D-Bus.
  """
  defdelegate call(conn, request), to: :dbus_rpc

  defdelegate call(conn, request, timeout), to: :dbus_rpc
end

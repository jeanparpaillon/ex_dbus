defmodule DBus.Interfaces.Peer do
  @moduledoc """
  Describe standard interface `org.freedesktop.DBus.Peer
  `

  See [D-Bus Peer Interface](https://dbus.freedesktop.org/doc/dbus-specification.html#standard-interfaces-peer)
  """
  use DBus.Schema

  node do
    interface "org.freedesktop.DBus.Peer" do
      method "Ping" do
      end

      method "GetMachineId" do
        arg("machine_uuid", "s", :out)
      end
    end
  end
end

defmodule MyIcon do
  @moduledoc false

  alias :dbus_method_call, as: MethodCall
  alias DBus.RPC
  alias MyIcon.Sup

  @bus_ref :session
  @service_name "org.example.MyIcon-#{:os.getpid()}-1"

  def start_link do
    Sup.start_link(@bus_ref, @service_name)
  end

  def register_icon do
    call =
      MethodCall.build(
        "RegisterStatusMotifierItem",
        "/StatusNotifierWatcher",
        {[:string], [@service_name]},
        interface: "org.kde.StatusNotifierWatcher",
        destination: "org.kde.StatusNotifierWatcher"
      )

    RPC.call(@bus_ref, call)
  end
end

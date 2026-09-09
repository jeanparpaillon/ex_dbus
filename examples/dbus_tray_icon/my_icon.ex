defmodule MyIcon do
  @moduledoc false

  alias DBus.Message
  alias DBus.RPC
  alias MyIcon.Sup

  @bus_ref :session
  @service_name "org.example.MyIcon-#{:os.getpid()}-1"

  def start_link do
    Sup.start_link(@bus_ref, @service_name)
  end

  def register_icon do
    call =
      "org.kde.StatusNotifierWatcher"
      |> Message.method_call("RegisterStatusMotifierItem")
      |> Message.destination("org.kde.StatusNotifierWatcher")
      |> Message.path("/StatusNotifierWatcher")
      |> Message.body([:string], [@service_name])

    conn = DBus.get_conn(@bus_ref)
    RPC.call(conn, call)
  end
end

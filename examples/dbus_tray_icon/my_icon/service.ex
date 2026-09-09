defmodule MyIcon.Service do
  @moduledoc false
  use DBus.Service

  alias DBus.Bus

  @impl true
  def init(opts) do
    bus = Keyword.fetch!(opts, :bus)
    name = Keyword.fetch!(opts, :name)
    icon = Keyword.fetch!(opts, :icon)
    menu = Keyword.fetch!(opts, :menu)

    with :ok <- can_register(bus) do
      {:ok, %{name: name, menu: menu, icon: icon}}
    end
  end

  # Gen server implementation

  @impl true
  def handle_call(_request, _from, state) do
    {:reply, {:error, :unknown_request}, state}
  end

  defp can_register(address) do
    bus = DBus.get_proxy(address)

    with {:ok, _} <- Bus.get_name_owner(bus, "org.kde.StatusNotifierWatcher"),
         {:ok, true} <-
           Bus.has_interface?(
             bus,
             "org.kde.StatusNotifierWatcher",
             "/StatusNotifierWatcher",
             "org.kde.StatusNotifierWatcher"
           ) do
      :ok
    else
      _ -> {:error, "Could not find valid StatusNotifierWatcher"}
    end
  end
end

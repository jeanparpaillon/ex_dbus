defmodule MyIcon.Sup do
  @moduledoc false

  def start_link(bus_ref, service_name) do
    icon_config = %{
      "Category" => "ApplicationStatus",
      "Id" => "1",
      "Title" => "test_icon",
      "Menu" => "/MenuBar",
      "Status" => "Active",
      "IconName" => "applications-development",
      "OverlayIconName" => "",
      "AttentionIconName" => "",
      "AttentionMovieName" => "",
      "ToolTip" => [
        {:dbus_variant, :string, "applications-development"},
        [],
        {:dbus_variant, :string, "test tooltip"},
        {:dbus_variant, :string, "some tooltip description here"}
      ],
      "ItemIsMenu" => false,
      "IconPixmap" => [],
      "OverlayIconPixmap" => [],
      "AttentionIconPixmap" => [],
      "WindowId" => 0
    }

    menu_config = %{
      "Version" => 3,
      "TextDirection" => "ltr",
      "Status" => "normal",
      "IconThemePath" => []
    }

    children = [
      {DBus, [bus_ref]},
      {IconConfig, config: icon_config, name: IconConfig},
      {MenuConfig, config: menu_config, name: MenuConfig},
      {MyIcon.Service, name: service_name, icon: IconConfig, menu: MenuConfig, bus: bus_ref}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

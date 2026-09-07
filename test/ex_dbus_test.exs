defmodule DBusTest do
  use ExUnit.Case
  doctest DBus

  test "greets the world" do
    assert DBus.hello() == :world
  end
end

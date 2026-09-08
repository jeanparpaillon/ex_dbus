defmodule MyIcon.Router do
  @moduledoc false
  use DBus.Router

  def method(path, interface, method, signature, args, context) do
    IO.inspect(
      [
        path,
        interface,
        method,
        signature,
        args,
        context
      ],
      label: "ROUTE METHOD"
    )

    :skip
  end

  def get_property(path, interface, property, context) do
    IO.inspect(
      [
        path,
        interface,
        property,
        context
      ],
      label: "ROUTE GET PROPERTY"
    )

    :skip
  end

  def set_property(path, interface, property, value, context) do
    IO.inspect(
      [
        path,
        interface,
        property,
        value,
        context
      ],
      label: "ROUTE SET PROPERTY"
    )

    :skip
  end
end

defprotocol DBus.Router.Protocol do
  alias DBus.Spec

  @fallback_to_any true

  @spec method(
          t(),
          path :: String.t(),
          interface :: String.t(),
          method :: String.t(),
          signature :: String.t(),
          args :: list(),
          context :: map()
        ) ::
          Spec.method_handle_return() | :skip
  def method(router, path, interface, method, signature, args, context)

  @spec get_property(
          t(),
          path :: String.t(),
          interface :: String.t(),
          property :: String.t(),
          context :: map()
        ) ::
          Spec.property_getter_return() | :skip
  def get_property(router, path, interface, property, context)

  @spec set_property(
          t(),
          path :: String.t(),
          interface :: String.t(),
          property :: String.t(),
          value :: any(),
          context :: map()
        ) ::
          Spec.property_setter_return() | :skip
  def set_property(router, path, interface, property, value, context)
end

defimpl DBus.Router.Protocol, for: Any do
  def method(_router, _path, _interface, _method, _signature, _args, _context), do: :skip

  def get_property(_router, _path, _interface, _property, _context), do: :skip

  def set_property(_router, _path, _interface, _property, _value, _context), do: :skip
end

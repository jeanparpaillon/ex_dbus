defmodule DBus.Interfaces.Properties do
  @moduledoc false
  use DBus.Schema
  alias DBus.DOM.Tree

  @interface "org.freedesktop.DBus.Properties"

  @timeout_error "org.freedesktop.DBus.Error.NoReply"
  @failed_error "org.freedesktop.DBus.Error.Failed"
  @unsupported_error "org.freedesktop.DBus.Error.NotSupported"
  @invalid_args_error "org.freedesktop.DBus.Error.InvalidArgs"

  node do
    interface "org.freedesktop.DBus.Properties" do
      method "Get" do
        arg("interface_name", "s", :in)
        arg("property_name", "s", :in)
        arg("value", "v", :out)
        callback(&__MODULE__.get/2)
      end

      method "GetAll" do
        arg("interface_name", "s", :in)
        arg("properties", "a{sv}", :out)
        callback(&__MODULE__.get_all/2)
      end

      method "Set" do
        arg("interface_name", "s", :in)
        arg("property_name", "s", :in)
        arg("value", "v", :in)
        callback(&__MODULE__.set/2)
      end

      signal "PropertiesChanged" do
        arg("interface_name", "s")
        arg("changed_properties", "a{sv}")
        arg("invalidated_properties", "as")
      end
    end
  end

  @doc """
  Forward `GetAll` to the object the context points at, as a single call.

  The local tree stays the contract: the reply is narrowed to the properties
  this node declares readable, so a peer that answers with more than we
  introspect does not widen the interface behind the schema's back.
  """
  def get_all(interface_name, %{node: object} = context) do
    with {:ok, interface} <- find_interface(object, interface_name),
         {:ok, values} <- rpc_call("GetAll", {[:string], [interface_name]}, context) do
      {:ok, [{:dict, :string, :variant}], [readable(interface, values)]}
    end
  end

  def get({interface_name, property_name}, %{node: object} = context) do
    with {:ok, interface} <- find_interface(object, interface_name),
         {:ok, property} <- find_property(interface, property_name),
         :ok <- can_read(property),
         args = {[:string, :string], [interface_name, property_name]},
         {:ok, value} <- rpc_call("Get", args, context) do
      cast_variant(value, property_name)
    end
  end

  def set({interface_name, property_name, value}, %{node: object} = context) do
    with {:ok, interface} <- find_interface(object, interface_name),
         {:ok, property} <- find_property(interface, property_name),
         :ok <- can_write(property),
         args = set_args(interface_name, property_name, value, property),
         {:ok, _} <- rpc_call("Set", args, context) do
      # `Set` declares no out argument: the reply carries nothing.
      {:ok, [], []}
    end
  end

  defp set_args(interface_name, property_name, value, property) do
    {[:string, :string, :variant], [interface_name, property_name, variant(value, property)]}
  end

  #
  # RPC
  #

  # The destination and the object path come from the call context, not from
  # the property: a node is a proxy for one remote object, so every property on
  # it is read from the same peer.
  defp rpc_call(member, args, %{path: path, destination: destination} = context)
       when is_binary(path) and is_binary(destination) do
    message =
      :dbus_method_call.build(member, path, args,
        interface: @interface,
        destination: destination
      )

    context
    |> rpc(message)
    |> cast_reply()
  rescue
    e ->
      {:error, @failed_error, Exception.message(e)}
  catch
    :exit, reason ->
      {:error, @timeout_error, inspect(reason)}
  end

  defp rpc_call(_member, _args, _context) do
    {:error, @unsupported_error,
     "Property access needs a :destination and a :path in the call context"}
  end

  # A node is backed either by a `dbus_proxy` -- which resolves its own
  # connection, and is what a node built on the erlang-dbus proxy behaviour
  # carries -- or by a bare connection. `dbus_proxy:rpc_call/2` runs
  # `dbus_rpc:call/2` in *this* process, and the connection routes a reply to
  # whichever process sent the call, so neither form blocks the proxy loop.
  defp rpc(%{proxy: proxy}, message) when not is_nil(proxy) do
    :dbus_proxy.rpc_call(proxy, message)
  end

  defp rpc(%{conn: conn}, message) when not is_nil(conn) do
    :dbus_rpc.call(conn, message)
  end

  defp rpc(_context, _message) do
    {:error, :no_transport}
  end

  defp cast_reply({:ok, body}), do: {:ok, body}

  # `dbus_error:cast/1` gives the error name alone when the peer sent no
  # message body.
  defp cast_reply({:error, {name, message}}) when is_binary(name) and is_binary(message) do
    {:error, name, message}
  end

  defp cast_reply({:error, name}) when is_binary(name), do: {:error, name, ""}

  defp cast_reply({:error, :timeout}), do: {:error, @timeout_error, "The peer did not reply"}

  defp cast_reply({:error, :no_transport}) do
    {:error, @unsupported_error, "Property access needs a :proxy or a :conn in the call context"}
  end

  defp cast_reply({:error, reason}), do: {:error, @failed_error, inspect(reason)}

  defp cast_variant({:dbus_variant, _, _} = value, _property_name) do
    {:ok, [:variant], [value]}
  end

  defp cast_variant(_value, property_name) do
    {:error, @invalid_args_error, "Property #{property_name} was not answered with a variant"}
  end

  #
  # Tree lookups
  #

  defp find_interface(object, interface) do
    case Tree.find_interface(object, interface) do
      :error ->
        {:error, "org.freedesktop.DBus.Error.UnknownInterface",
         "Interface #{interface} not found at given path"}

      success ->
        success
    end
  end

  defp find_property({:interface, interface_name, _} = interface, property_name) do
    case Tree.find_property(interface, property_name) do
      :error ->
        {:error, "org.freedesktop.DBus.Error.UnknownProperty",
         "Property #{property_name} not found in interface #{interface_name} at given path"}

      success ->
        success
    end
  end

  # An incoming `a{sv}` unmarshals to a map; a list of pairs is accepted too,
  # since that is what the marshaller takes on the way out.
  defp readable(interface, values) when is_map(values) do
    Map.take(values, readable_names(interface))
  end

  defp readable(interface, values) when is_list(values) do
    names = readable_names(interface)
    Enum.filter(values, fn {name, _value} -> name in names end)
  end

  defp readable(_interface, _values), do: %{}

  defp readable_names(interface) do
    interface
    |> Tree.get_properties()
    |> Enum.filter(&(Tree.property_access(&1) in [:read, :readwrite]))
    |> Enum.map(&Tree.property_name/1)
  end

  defp can_read(property) do
    case Tree.property_access(property) do
      access when access in [:read, :readwrite] ->
        :ok

      _ ->
        {:error, "org.freedesktop.DBus.Error.AccessDenied", "The property is not readable"}
    end
  end

  defp can_write(property) do
    case Tree.property_access(property) do
      access when access in [:write, :readwrite] ->
        :ok

      _ ->
        {:error, "org.freedesktop.DBus.Error.PropertyReadOnly", "The property is read-only"}
    end
  end

  defp variant({:dbus_variant, _, _} = value, _property), do: value

  defp variant(value, property) do
    {:dbus_variant, single_type(Tree.property_type(property)), value}
  end

  defp single_type(type) do
    {:ok, [utype]} = :dbus_marshaller.unmarshal_signature(type)
    utype
  end
end

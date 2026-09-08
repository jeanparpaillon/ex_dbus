defmodule DBus.DOM.Builder do
  @moduledoc false
  use DBus.DOM.Spec, prefix: false

  @spec service(name()) :: {:ok, service()}
  def service(name) do
    {:ok, {:service, name, []}}
  end

  @spec service!(name()) :: service()
  def service!(name) do
    {:ok, service} = service(name)
    service
  rescue
    _ ->
      {:error, {:invalid_service, name}}
  end

  @spec root(name()) :: {:ok, object()}
  def root(name \\ "/") do
    object(name)
  end

  @spec root!(name()) :: object()
  def root!(name \\ "/") do
    {:ok, object} = root(name)
    object
  rescue
    _ ->
      {:error, {:invalid_object, name}}
  end

  @spec object(name) :: {:ok, object()}
  def object(name) when is_binary(name) do
    {:ok, {:object, name, []}}
  end

  @spec object!(name) :: object()
  def object!(name) do
    {:ok, object} = object(name)
    object
  rescue
    _ ->
      {:error, {:invalid_object, name}}
  end

  @spec interface(name) :: {:ok, interface()}
  def interface(name) when is_binary(name) do
    {:ok, {:interface, name, []}}
  end

  @spec interface!(name) :: interface()
  def interface!(name) do
    {:ok, interface} = interface(name)
    interface
  rescue
    _ ->
      {:error, {:invalid_interface, name}}
  end

  @spec annotation(name, binary() | number() | boolean()) ::
          {:ok, annotation()} | {:error, binary()}
  def annotation(name, value \\ true)

  def annotation(name, value) when is_binary(value) do
    {:ok, {:annotation, name, value}}
  end

  def annotation(name, value) when is_boolean(value) or is_number(value) do
    annotation(name, to_string(value))
  end

  @spec annotation!(name(), binary() | number() | boolean()) :: annotation()
  def annotation!(name, value \\ true) do
    {:ok, annotation} = annotation(name, value)
    annotation
  rescue
    _ ->
      {:error, {:invalid_annotation, name}}
  end

  @spec signal(name) :: {:ok, signal()}
  def signal(name) when is_binary(name) do
    {:ok, {:signal, name, []}}
  end

  @spec signal!(name) :: signal()
  def signal!(name) do
    {:ok, signal} = signal(name)
    signal
  rescue
    _ ->
      {:error, {:invalid_signal, name}}
  end

  @spec method(name()) :: {:ok, method()}
  def method(name) do
    {:ok, {:method, name, [], nil}}
  end

  @spec method!(name()) :: method()
  def method!(name) do
    {:ok, method} = method(name)
    method
  rescue
    _ ->
      {:error, {:invalid_method, name}}
  end

  @spec property(name(), dbus_type(), access()) :: {:ok, property()}
  def property(name, type, access) do
    {:ok, {:property, name, type, access, [], {nil, nil}}}
  end

  @spec property!(name(), dbus_type(), access()) :: property()
  def property!(name, type, access) do
    {:ok, property} = property(name, type, access)
    property
  end

  @spec argument(name(), dbus_type(), direction()) :: {:ok, argument()}
  def argument(name, type, direction \\ :out) do
    {:ok, {:argument, name, type, direction, []}}
  end

  @spec argument!(name(), dbus_type(), direction()) :: argument()
  def argument!(name, type, direction \\ :out) do
    {:ok, argument} = argument(name, type, direction)
    argument
  end

  @spec set_method_callback!(method(), method_handle()) :: method()
  def set_method_callback!({:method, name, children, _}, callback) when is_function(callback) do
    {:method, name, children, callback}
  end

  @spec set_property_getter!(property(), property_getter()) :: property()
  def set_property_getter!({:property, name, type, access, annotations, {_, setter}}, getter)
      when is_function(getter) do
    {:property, name, type, access, annotations, {getter, setter}}
  end

  @spec set_property_setter!(property(), property_setter()) :: property()
  def set_property_setter!({:property, name, type, access, annotations, {getter, _}}, setter)
      when is_function(setter) do
    {:property, name, type, access, annotations, {getter, setter}}
  end
end

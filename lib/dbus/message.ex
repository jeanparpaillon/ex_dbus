defmodule DBus.Message do
  @moduledoc """
  Elixir flavoured :dbus_message
  """
  require Record

  Record.defrecord(
    :dbus_message,
    Record.extract(:dbus_message, from_lib: "dbus/include/dbus.hrl")
  )

  @type t :: record(:dbus_message)

  @type field() ::
          :invalid
          | :path
          | :interface
          | :member
          | :error_name
          | :reply_serial
          | :destination
          | :sender
          | :signature
          | :unix_fds

  defdelegate get_serial(message), to: :dbus_message
  defdelegate set_serial(message, serial), to: :dbus_message
  defdelegate get_type(message), to: :dbus_message
  defdelegate get_body(message), to: :dbus_message
  defdelegate fd(index, message), to: :dbus_message

  @spec find_field(t(), field()) :: term()
  def find_field(message, field),
    do: find_field(message, field, :undefined)

  @spec find_field(t(), field(), term()) :: term()
  [
    invalid: 0,
    path: 1,
    interface: 2,
    member: 3,
    error_name: 4,
    reply_serial: 5,
    destination: 6,
    sender: 7,
    signature: 8,
    unix_fds: 9
  ]
  |> Enum.each(fn {name, code} ->
    def find_field(message, unquote(name), default) do
      :dbus_message.find_field(message, unquote(code), default)
    end
  end)

  def find_field(_message, field, _default),
    do: raise("Unknown field: #{field}")
end

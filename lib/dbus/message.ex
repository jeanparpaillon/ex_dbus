defmodule DBus.Message do
  @moduledoc """
  Elixir flavoured :dbus_message
  """
  require Record

  Record.defrecord(
    :dbus_message,
    Record.extract(:dbus_message, from_lib: "dbus/include/dbus.hrl")
  )

  @type t() :: record(:dbus_message)

  @type path :: String.t()
  @type interface :: String.t()
  @type member :: String.t()
  @type error_name :: String.t()
  @type reply_serial :: non_neg_integer()
  @type destination :: String.t()
  @type sender :: String.t()
  @type signature_field :: signature()
  @type unix_fds :: non_neg_integer()

  @type type() ::
          :byte
          | :boolean
          | :int16
          | :uint16
          | :int32
          | :uint32
          | :int64
          | :uint64
          | :double
          | :unix_fd
          | :string
          | :object_path
          | :signature
          | {:array, type()}
          | {:struct, [type()]}
          | :variant
          | {:dict, type(), type()}
          | :empty

  @type signature() :: [type()]

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

  def get_body(message) do
    case :dbus_message.get_body(message) do
      :undefined -> nil
      body -> body
    end
  end

  defdelegate fd(index, message), to: :dbus_message

  @spec find_field(t(), field()) :: term() | nil
  def find_field(message, field),
    do: find_field(message, field, nil)

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
      :dbus_message.find_field(unquote(code), message, default)
    end
  end)

  def find_field(_message, field, _default) when is_atom(field),
    do: raise("Unknown field: #{field}")
end

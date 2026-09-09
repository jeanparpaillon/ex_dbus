defmodule DBus.Message do
  @moduledoc """
  Functions for building D-Bus messages
  """
  alias DBus.DOM.Builder.Finder
  alias DBus.Schema

  import Bitwise

  require Record

  Record.defrecord(
    :dbus_message,
    Record.extract(:dbus_message, from_lib: "dbus/include/dbus.hrl")
  )

  @type t() :: record(:dbus_message)

  Record.defrecord(
    :dbus_header,
    Record.extract(:dbus_header, from_lib: "dbus/include/dbus.hrl")
  )

  @type header() :: record(:dbus_header)

  Record.defrecord(
    :dbus_variant,
    Record.extract(:dbus_variant, from_lib: "dbus/include/dbus.hrl")
  )

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

  @type message_type() ::
          :invalid
          | :method_call
          | :method_return
          | :error
          | :signal

  @message_type_code %{
    :invalid => 0,
    :method_call => 1,
    :method_return => 2,
    :error => 3,
    :signal => 4
  }

  @message_type_name Map.new(@message_type_code, fn {name, code} -> {code, name} end)

  @flag_no_reply_expected 1
  @flag_no_auto_start 2
  @flag_allow_interactive_authorization 4

  @doc """
  Creates a method_call with plain interface and member name
  """
  @spec method_call(interface(), member()) :: t()
  def method_call(interface, member) do
    dbus_message()
    |> type(:method_call)
    |> interface(interface)
    |> member(member)
  end

  @doc """
  Creates a new D-Bus method call message with the given interface and member.
  """
  @spec method_call(module(), interface(), member()) :: t()
  def method_call(schema, interface, member)
      when is_atom(schema) and is_binary(interface) and is_binary(member) do
    dbus_message()
    |> type(:method_call)
    |> interface(interface)
    |> member(member)
    |> when_valid(&validate_schema(&1, schema, :method))
  end

  @doc """
  Returns a message of type method_return from given method_call
  """
  @spec method_return(t()) :: t()
  def method_return(orig) do
    case type(orig) do
      :method_call ->
        dbus_message()
        |> type(:method_return)
        |> reply_serial(serial(orig))
        |> destination(sender(orig))

      _ ->
        dbus_message()
        |> add_error(:type, "origin message is not a method call")
    end
  end

  @doc """
  Creates a message of type signal
  """
  @spec signal(module(), interface(), member()) :: t()
  def signal(schema, interface, member)
      when is_atom(schema) and is_binary(interface) and is_binary(member) do
    dbus_message()
    |> type(:signal)
    |> interface(interface)
    |> member(member)
    |> when_valid(&validate_schema(&1, schema, :signal))
  end

  @doc """
  Returns a message of type error, from a method_call
  """
  @spec error(t(), error_name()) :: t()
  def error(orig, error_name) do
    case type(orig) do
      t when t in [:method_call, :signal] ->
        dbus_message()
        |> type(:error)
        |> serial(serial(orig))
        |> error_name(error_name)

      _ ->
        dbus_message()
        |> add_error(:type, "origin message is not a method_call or signal")
    end
  end

  @doc """
  Returns message type
  """
  @spec type(t()) :: message_type()
  def type(message) do
    code =
      message
      |> dbus_message(:header)
      |> dbus_header(:type)

    Map.get(@message_type_name, code, :invalid)
  end

  @doc """
  Set message type
  """
  @spec type(t(), message_type()) :: t()
  def type(message, :invalid) do
    add_error(message, :type, :invalid)
  end

  def type(message, type) do
    case @message_type_code[type] do
      nil ->
        add_error(message, :type, :invalid)

      code ->
        # `#dbus_header.type` holds the wire code, not the name: `marshal_header/1`
        # writes it as a `byte`.
        header =
          message
          |> dbus_message(:header)
          |> dbus_header(type: code)

        dbus_message(message, header: header)
    end
  end

  @doc """
  Returns error_name field
  """
  @spec error_name(t()) :: error_name() | nil
  def error_name(message) do
    find_field(message, :error_name)
  end

  @doc """
  Sets the error_name field
  """
  @spec error_name(t(), error_name()) :: t()
  def error_name(message, error_name) do
    error_name_field = build_field(:error_name, error_name)

    add_header_field(message, error_name_field)
  end

  @doc """
  Returns reply_serial field
  """
  @spec reply_serial(t()) :: reply_serial()
  def reply_serial(message) do
    find_field(message, :reply_serial, 0)
  end

  @doc """
  Set reply_serial field
  """
  @spec reply_serial(t(), reply_serial()) :: t()
  def reply_serial(message, reply_serial) do
    reply_serial_field = build_field(:reply_serial, reply_serial)

    add_header_field(message, reply_serial_field)
  end

  @doc """
  Returns message interface
  """
  @spec interface(t()) :: String.t() | nil
  def interface(message) do
    find_field(message, :interface)
  end

  @doc """
  Set message interface
  """
  @spec interface(t(), interface()) :: t()
  def interface(message, interface) do
    interface_field = build_field(:interface, interface)

    add_header_field(message, interface_field)
  end

  @doc """
  Returns message member
  """
  @spec member(t()) :: String.t() | nil
  def member(message) do
    find_field(message, :member)
  end

  @doc """
  Set message member
  """
  @spec member(t(), member()) :: t()
  def member(message, member) do
    member_field = build_field(:member, member)

    add_header_field(message, member_field)
  end

  @doc """
  Returns message sender
  """
  @spec sender(t()) :: sender()
  def sender(message) do
    find_field(message, :sender)
  end

  @doc """
  Validate interface and member against schema

  If valid, set body signature
  """
  @spec validate_schema(t(), module(), atom()) :: t()
  def validate_schema(message, mod, type) do
    interface_name = interface(message)
    member_name = member(message)

    with {:schema, {:ok, schema}} <- {:schema, Schema.schema(mod)},
         {:interface, {:ok, interface}} <-
           {:interface, Finder.find(schema, interface_name)},
         {:member, {:ok, member}} <-
           {:member, find_member(interface, member_name, type)} do
      signature = member_signature(member)

      message
      |> dbus_message(body_sig: signature)
    else
      {:schema, {:error, reason}} ->
        add_error(message, :schema, reason)

      {:interface, :error} ->
        add_error(message, :interface, :not_found)

      {:member, {:error, reason}} ->
        add_error(message, :member, reason)
    end
  end

  @doc """
  Returns message path
  """
  @spec path(t()) :: path() | nil
  def path(message) do
    find_field(message, :path)
  end

  @doc """
  Set message path
  """
  @spec path(t(), path()) :: t()
  def path(message, path) do
    path_field = build_field(:path, path)

    add_header_field(message, path_field)
  end

  @doc """
  Returns body signature
  """
  @spec signature(t()) :: signature()
  def signature(message) do
    dbus_message(message, :body_sig)
  end

  @doc """
  Returns message body
  """
  @spec body(t()) :: any()
  def body(message) do
    dbus_message(message, :body)
  end

  @doc """
  Set body with given signature
  """
  @spec body(t(), signature(), any()) :: t()
  def body(message, signature, body) do
    message
    |> dbus_message(body_sig: signature, body: body)
  end

  @doc """
  Set body
  """
  @spec body(t(), any()) :: t()
  def body(message, body) do
    message
    |> dbus_message(body: body)
  end

  @doc """
  Returns message destination
  """
  @spec destination(t()) :: destination() | nil
  def destination(message) do
    find_field(message, :destination)
  end

  @doc """
  Set message destination
  """
  @spec destination(t(), destination()) :: t()
  def destination(message, destination) do
    destination_field = build_field(:destination, destination)

    add_header_field(message, destination_field)
  end

  @doc """
  Returns no_reply_expected flag
  """
  @spec no_reply_expected?(t()) :: boolean()
  def no_reply_expected?(message) do
    get_header_flag(message, @flag_no_reply_expected)
  end

  @doc """
  Set no_reply_expected option, if message is a method_call
  """
  @spec no_reply_expected(t()) :: t()
  def no_reply_expected(message) do
    case type(message) do
      :method_call ->
        set_header_flag(message, @flag_no_reply_expected)

      _ ->
        message
    end
  end

  @doc """
  Returns no_auto_start flag
  """
  @spec no_auto_start?(t()) :: boolean()
  def no_auto_start?(message) do
    get_header_flag(message, @flag_no_auto_start)
  end

  @doc """
  Set no_auto_start option, if message is a method_call
  """
  @spec no_auto_start(t()) :: t()
  def no_auto_start(message) do
    case type(message) do
      :method_call ->
        set_header_flag(message, @flag_no_auto_start)

      _ ->
        message
    end
  end

  @doc """
  Returns allow_interactive_authorization flag
  """
  @spec allow_interactive_authorization?(t()) :: boolean()
  def allow_interactive_authorization?(message) do
    get_header_flag(message, @flag_allow_interactive_authorization)
  end

  @doc """
  Set allow_interactive_authorization option, if message is a method_call
  """
  @spec allow_interactive_authorization(t()) :: t()
  def allow_interactive_authorization(message) do
    case type(message) do
      :method_call ->
        set_header_flag(message, @flag_allow_interactive_authorization)

      _ ->
        message
    end
  end

  @doc """
  Returns message serial
  """
  @spec serial(t()) :: non_neg_integer()
  def serial(message) do
    message
    |> dbus_message(:header)
    |> dbus_header(:serial)
  end

  @doc """
  Set message serial
  """
  @spec serial(t(), reply_serial()) :: t()
  def serial(message, serial) when is_integer(serial) and serial > 0 do
    header =
      message
      |> dbus_message(:header)
      |> dbus_header(serial: serial)

    message
    |> dbus_message(header: header)
  end

  def serial(message, _) do
    add_error(message, :serial, :invalid)
  end

  @doc """
  Returns true if any error in the message construction
  """
  @spec errors?(t()) :: boolean()
  def errors?(message) do
    not Enum.empty?(dbus_message(message, :errors))
  end

  @doc """
  Add error to accumulator
  """
  @spec add_error(t(), atom(), term()) :: t()
  def add_error(message, field, reason) do
    errors =
      message
      |> dbus_message(:errors)
      |> Map.update(field, [reason], fn existing -> [reason | existing] end)

    dbus_message(message, errors: errors)
  end

  @field_specs [
    invalid: {0, nil},
    path: {1, :object_path},
    interface: {2, :string},
    member: {3, :string},
    error_name: {4, :string},
    reply_serial: {5, :uint32},
    destination: {6, :string},
    sender: {7, :string},
    signature: {8, :signature},
    unix_fds: {9, :uint32}
  ]

  @spec find_field(t(), field()) :: term() | nil
  def find_field(message, field),
    do: find_field(message, field, nil)

  @spec find_field(t(), field(), term()) :: term()
  @field_specs
  |> Enum.each(fn {name, {code, _type}} ->
    def find_field(message, unquote(name), default) do
      unquote(code)
      |> :dbus_message.find_field(message, default)
      |> unwrap_field()
    end
  end)

  def find_field(_message, field, _default) when is_atom(field),
    do: raise("Unknown field: #{field}")

  @field_specs
  |> Enum.each(fn {name, {code, type}} ->
    def build_field(unquote(name), value) do
      {unquote(code), dbus_variant(type: unquote(type), value: value)}
    end
  end)

  defdelegate fd(index, message), to: :dbus_message

  @doc """
  Execute fun on the message if it is valid, else returns message as is
  """
  @spec when_valid(t(), (t() -> t())) :: t()
  def when_valid(message, fun) do
    if errors?(message) do
      message
    else
      fun.(message)
    end
  end

  ###
  ### Private
  ###

  # `build_field/2` wraps a header field value in a `dbus_variant`, which is what
  # `dbus_marshaller` needs to write the `a(yv)` header field array. A message
  # coming off the wire holds the bare value instead, because unmarshalling a
  # variant yields the value alone. Accessors have to read both.
  defp unwrap_field(dbus_variant(value: value)), do: value
  defp unwrap_field(value), do: value

  defp add_header_field(message, field) do
    header = dbus_message(message, :header)
    fields = dbus_header(header, :fields)

    header =
      header
      |> dbus_header(fields: [field | fields])

    dbus_message(message, header: header)
  end

  # The finders return the signature as it is written in the schema, e.g. "su".
  # `body_sig` holds the parsed form, `[:string, :uint32]`.
  defp member_signature({:method, _, _, _} = method) do
    method
    |> Finder.get_method_signature()
    |> parse_signature()
  end

  defp member_signature({:signal, _, _} = signal) do
    signal
    |> Finder.get_signal_signature()
    |> parse_signature()
  end

  defp parse_signature(signature) do
    {:ok, parsed} = :dbus_marshaller.unmarshal_signature(signature)
    parsed
  end

  defp set_header_flag(message, flag) do
    header = dbus_message(message, :header)
    flags = dbus_header(header, :flags)
    flags = flags |> bor(flag)

    header = dbus_header(header, flags: flags)
    dbus_message(message, header: header)
  end

  defp get_header_flag(message, flag) do
    header = dbus_message(message, :header)
    flags = dbus_header(header, :flags)
    (flags &&& flag) != 0
  end

  defp find_member(interface, member_name, :method) do
    case Finder.find(interface, member_name) do
      {:ok, {:method, _, _, _} = method} ->
        {:ok, method}

      _ ->
        {:error, :not_found}
    end
  end

  defp find_member(interface, member_name, :signal) do
    case Finder.find(interface, member_name) do
      {:ok, {:signal, _, _} = signal} ->
        {:ok, signal}

      _ ->
        {:error, :not_found}
    end
  end
end

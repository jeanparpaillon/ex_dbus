defmodule DBus.XML do
  @moduledoc false
  use DBus.DOM.Spec, prefix: false
  alias DBus.DOM

  @doctype "<!DOCTYPE node PUBLIC \"-//freedesktop//DTD D-BUS Object Introspection 1.0//EN\" \"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd\">"

  @spec to_xml(definition(), keyword()) :: binary()
  def to_xml(definition, opts \\ []) do
    definition
    |> DOM.XML.to_xml(opts)
    |> Saxy.encode!(encoding: :utf8)
    |> inject_doctype()
  end

  defp inject_doctype(xml) do
    String.replace(xml, ~r/(<\?xml[^>]*>)/, "#{@doctype}")
  end
end

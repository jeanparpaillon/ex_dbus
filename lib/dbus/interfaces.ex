defmodule DBus.Interfaces do
  use DBus.Schema
  alias DBus.Interfaces.{Introspectable, Peer, Properties}

  node do
    import from(Introspectable)
    import from(Peer)
    import from(Properties)
  end
end

defmodule DBus.Interfaces.Bus do
  @moduledoc false
  use DBus.Schema

  node do
    interface "org.freedesktop.DBus" do
      method "Hello" do
        arg("unique_name", "s", :out)
      end

      method "RequestName" do
        arg("name", "s", :in)
        arg("flags", "u", :in)
        arg("result", "u", :out)
      end

      method "ReleaseName" do
        arg("name", "s", :in)
        arg("result", "u", :out)
      end

      method "ListQueuedOwners" do
        arg("name", "s", :in)
        arg("owners", "as", :out)
      end

      method "ListNames" do
        arg("names", "as", :out)
      end

      method "ListActivableNames" do
        arg("names", "as", :out)
      end

      method "NameHasOwner" do
        arg("name", "s", :in)
        arg("has_owner", "b", :out)
      end

      signal "NameOwnerChanged" do
        arg("name", "s")
        arg("old_owner", "s")
        arg("new_owner", "s")
      end

      signal "NameLost" do
        arg("name", "s")
      end

      signal "NameAcquired" do
        arg("name", "s")
      end

      signal "ActivatableServicesChanged" do
      end

      method "StartServiceByName" do
        arg("name", "s", :in)
        arg("flags", "u", :in)
        arg("result", "u", :out)
      end

      method "UpdateActivationEnvironment" do
        arg("environment", "a{ss}", :in)
      end

      method "GetNameOwner" do
        arg("name", "s", :in)
        arg("owner", "s", :out)
      end

      method "GetConnectionUnixUser" do
        arg("bus_name", "s", :in)
        arg("uid", "u", :out)
      end

      method "GetConnectionUnixProcessID" do
        arg("bus_name", "s", :in)
        arg("pid", "u", :out)
      end

      method "GetConnectionCredentials" do
        arg("bus_name", "s", :in)
        arg("credentials", "a{sv}", :out)
      end

      method "GetAdtAuditSessionData" do
        arg("bus_name", "s", :in)
        arg("audit_session_data", "ay", :out)
      end

      method "GetConnectionSELinuxSecurityContext" do
        arg("bus_name", "s", :in)
        arg("security_context", "s", :out)
      end

      method "AddMatch" do
        arg("rule", "s", :in)
      end

      method "RemoveMatch" do
        arg("rule", "s", :in)
      end

      method "GetId" do
        arg("id", "s", :out)
      end
    end
  end
end

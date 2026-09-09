defmodule DBus.Bus.ServiceMonitor do
  @moduledoc """
  Dedicated process for monitoring services attached to a `m:DBus.Bus` proxy

  As a callback module, `DBus.Bus` does not directly receive process events.
  """
  use GenServer

  alias DBus.Bus

  @spec start_link :: GenServer.on_start()
  def start_link do
    GenServer.start_link(__MODULE__, [self()])
  end

  @spec monitor(GenServer.server(), String.t(), pid()) :: :ok
  def monitor(ref, name, service) do
    GenServer.cast(ref, {:monitor, name, service})
  end

  @spec get_service(GenServer.server(), String.t()) :: {:ok, pid()} | :error
  def get_service(ref, name) do
    GenServer.call(ref, {:get_service, name})
  end

  @impl true
  def init([bus]) do
    _ = Process.flag(:trap_exit, true)
    {:ok, %{bus: bus, services: %{}}}
  end

  @impl true
  def handle_call({:get_service, name}, _from, state) do
    reply =
      case Map.get(state.services, name) do
        {service, _ref} -> {:ok, service}
        nil -> :error
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_cast({:monitor, name, service}, state) do
    ref = Process.monitor(service)
    {:noreply, %{state | services: Map.put(state.services, name, {service, ref})}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    state =
      state.services
      |> Enum.find(fn
        {_, {^pid, ^ref}} -> true
        _ -> false
      end)
      |> case do
        {name, _} -> unmonitor(name, state)
        nil -> state
      end

    {:noreply, state}
  end

  defp unmonitor(name, state) do
    case Map.pop(state.services, name) do
      {{_service, ref}, new_services} ->
        Process.demonitor(ref, [:flush])
        Bus.unregister_service(state.bus, name)
        %{state | services: new_services}

      {nil, new_services} ->
        %{state | services: new_services}
    end
  end
end

defmodule Application.Monitor do
  use GenServer
  require Logger
  alias DartMessagingServer.DynamicSupervisor
  alias Util.RegistryHelper

  @moduledoc """
  Mother process for a user. Holds state for devices, messages, etc.
  Survives socket termination.
  """

  # Detached start to avoid linking to the caller
  def start_link(eid) do
    GenServer.start(__MODULE__, eid, name: RegistryHelper.via_monitor_registry(eid))
  end

  @impl true
  def init(eid) do
    Logger.info("MotherServer init for user_id=#{eid}")
    {:ok, %{eid: eid, devices: %{}}}
  end

  # Start a device session under this Mother
  def start_device(eid, { eid, device_id, ws_pid}) do
    GenServer.call(RegistryHelper.via_monitor_registry(eid), {:start_device, {eid, device_id, ws_pid}})
  end

  @impl true
  def handle_call({:start_device, {eid, device_id, ws_pid}}, _from, state) do
    case DynamicSupervisor.start_session({eid, device_id, ws_pid}) do
      {:ok, pid} ->
        # Track device session PID in Mother's state
        devices = Map.put(state.devices, device_id, pid)
        {:reply, {:ok, pid}, %{state | devices: devices}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Optional: remove device when session dies
  @impl true
  def handle_cast({:remove_device, device_id}, state) do
    devices = Map.delete(state.devices, device_id)
    {:noreply, %{state | devices: devices}}
  end
  
end

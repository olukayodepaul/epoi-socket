defmodule Application.Monitor do
  use GenServer
  require Logger
  alias DartMessagingServer.DynamicSupervisor
  alias Util.RegistryHelper
  alias App.Devices.Cache

  @moduledoc """
  Mother process for a user. Holds state for devices, messages, etc.
  Survives socket termination.
  """
  def start_link(eid) do
    GenServer.start(__MODULE__, eid, name: RegistryHelper.via_monitor_registry(eid))
  end

  @impl true
  def init(eid) do
    Logger.info("Monitor init for eid=#{eid}")
    Cache.init()
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
        devices = Map.put(state.devices, device_id, pid)
        {:reply, {:ok, pid}, %{state | devices: devices}}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:get_startup_status, %{eid: eid, device_id: device_id, ws_pid: _ws_pid}}, state) do
    #send presence stattus to all the subscriber
    case Cache.fetch(device_id) do
      {:ok} -> :ok
      {:error} -> 
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        device = %App.Devices.Device{
          device_id: device_id,
          eid: eid,
          last_seen: now,
          status: "online",
          last_received_version: 0,   # initialize version if needed
          ip_address: nil,
          app_version: nil,
          os: nil,
          last_activity: now,
          supports_notifications: true,
          supports_media: true,
          inserted_at: now
        }
        Cache.save(device)
    end
    {:noreply, state}
  end

  @impl true
  def handle_cast({:terminate_child_process, {eid, device_id}}, state) do
  #check terminate and ping pong if both are working
  # close Mother if all the children are not avalaible.
    Cache.delete_only_ets(device_id)
    case Cache.all_by_user(eid) do
      [] ->
        {:stop, :normal, state}
      _ ->
        {:noreply, state}
    end
  end

end

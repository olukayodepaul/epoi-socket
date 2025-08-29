defmodule Application.Monitor do
  use GenServer
  require Logger

  alias DartMessagingServer.DynamicSupervisor
  alias Util.RegistryHelper
  alias App.AllRegistry
  alias Storage.{GlobalSubscriberCache, PgDeviceCache, PgDevicesSchema}
  alias Bicp.MonitorAppPresence
  alias DevicePresenceAggregator

  @moduledoc """
  Mother process for a user. Holds state for devices, messages, etc.
  Survives socket termination and monitors device presence.
  """


  def start_link(eid) do
    GenServer.start(__MODULE__, eid, name: RegistryHelper.via_monitor_registry(eid))
  end

  @impl true
  def init(eid) do
    Logger.info("Monitor init for eid=#{eid}")
    PgDeviceCache.init(eid)
    GlobalSubscriberCache.init(eid)

    {:ok, %{eid: eid, devices: %{}}}
  end

  # Device session start
  def start_device(eid, {eid, device_id, ws_pid}) do
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

  # Device registration
  @impl true
  def handle_cast({:monitor_startup_status, %{eid: eid, device_id: device_id, ws_pid: ws_pid}}, state) do

    IO.inspect("monitor_startup_status")
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case PgDeviceCache.fetch(device_id, eid, ws_pid) do
      {:ok} -> :ok
      {:error} ->
        device = %PgDevicesSchema{
          device_id: device_id,
          eid: eid,
          last_seen: now,
          ws_pid: :erlang.pid_to_list(ws_pid) |> to_string(),
          status: "ONLINE",
          last_received_version: 0,
          ip_address: nil,
          app_version: nil,
          os: nil,
          last_activity: now,
          supports_notifications: true,
          supports_media: true,
          status_source: "LOGIN",
          awareness_intention: 0,
          inserted_at: now
        }
        PgDeviceCache.save(device, eid)
    end

    AllRegistry.sent_subscriber(device_id, eid, GlobalSubscriberCache.fetch_subscriber_by_owners_eid(eid))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:push_subscriber_update_to_monitor, %{from: from, to: to, device_id: device_id, status: status}}, state) do
    GlobalSubscriberCache.put_subscribers(to, from, device_id, status)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:monitor_pong_counter, {eid, device_id, status}}, state) do
    track_state_change(eid)
    PgDeviceCache.update_status(eid, device_id, "PONG", status)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:monitor_terminate_child, {eid, device_id}}, state) do
    PgDeviceCache.update_status(eid, device_id, "LOGOUT", "OFFLINE")
    track_state_change(eid)
    {:noreply, state}
  end

  def track_state_change(owner_eid) do
    case DevicePresenceAggregator.track_state_change(owner_eid) do
      {:changed, user_status, online_devices} -> 
        IO.inspect({:changed, user_status, online_devices})
        :ok
      {:unchanged, _user_status, _online_devices} -> 
        IO.inspect({:unchanged})
        :ok
    end
  end

  # Catch-all for unexpected messages
  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unhandled message in Mother: #{inspect(msg)}")
    {:noreply, state}
  end


end



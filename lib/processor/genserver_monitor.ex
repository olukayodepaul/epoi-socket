defmodule Application.Monitor do
  use GenServer
  require Logger

  alias DartMessagingServer.DynamicSupervisor
  alias Util.{RegistryHelper}
  alias Storage.{GlobalSubscriberCache, PgDeviceCache, PgDevicesSchema}
  alias Bicp.MonitorAppPresence
  alias Global.StateChange

  def start_link(eid) do
    GenServer.start(__MODULE__, eid, name: RegistryHelper.via_monitor_registry(eid))
  end

  @impl true
  def init(eid) do
    Logger.info("Monitor init for eid=#{eid}")
    PgDeviceCache.init(eid)
    GlobalSubscriberCache.init(eid)
    MonitorAppPresence.subscribe_to_friends(eid)
    MonitorAppPresence.user_level_subscribtion(eid)
    {:ok, %{eid: eid, current_timer: nil, devices: %{}}}
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

  # client registration
  # send notification to all subscribers
  @impl true
  def handle_cast({:m_setup_client_init, %{eid: eid, device_id: device_id, ws_pid: ws_pid}}, state) do
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
          awareness_intention: 2,
          inserted_at: now
        }
        #using what is inserte
        PgDeviceCache.save(device, eid)
    end
    case StateChange.track_state_change(eid) do
      {:changed, user_status, _online_devices} ->
        device = PgDeviceCache.get(eid, device_id)
        MonitorAppPresence.broadcast_awareness(device.eid, device.awareness_intention)
        :ok
      {:unchanged, _user_status, _online_devices} ->
        :ok
    end
    StateChange.cancel_termination_if_all_offline(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_pong, {eid, device_id, status}}, state) do
    PgDeviceCache.update_status(eid, device_id, "PONG", status)
    case StateChange.track_state_change(eid) do
      {:changed, user_status, _online_devices} ->
        device = PgDeviceCache.get(eid, device_id)
        MonitorAppPresence.broadcast_awareness(device.eid, device.awareness_intention, user_status)
        :ok
      {:unchanged, _user_status, _online_devices} ->
        :ok
    end
    {:noreply, state}
  end

  def handle_cast({:monitor_handle_logout, %{device_id: device_id, eid: eid}}, state) do
    IO.inspect("monitor_handle_logout here")
    PgDeviceCache.update_status_without_last_see(eid, device_id, "LOGOUT", "OFFLINE")
    StateChange.schedule_termination_if_all_offline(state)
    case StateChange.track_state_change(eid) do
      {:changed, user_status, _online_devices} ->
        IO.inspect({"chage monitor_handle_logout here", user_status})
        device = PgDeviceCache.get(eid, device_id)
        MonitorAppPresence.broadcast_awareness(device.eid, device.awareness_intention, user_status)
        :ok
      {:unchanged, _user_status, _online_devices} ->
        :ok
    end
    {:noreply, state}
  end

  #still need to make adjustment to this
  @impl true
  def handle_info({:awareness_update, %Strucs.Awareness{} = awareness}, %{eid: eid} = state) do
    MonitorAppPresence.fan_out_to_children(eid, awareness)
    {:noreply, state}
  end

  def handle_info(:terminate_process, state) do
    Logger.info("No activity during grace period. Terminating mother for #{state.eid}")
    StateChange.cancel_termination_if_all_offline(state)
    {:stop, :normal, state}
  end

  # Catch-all for unexpected messages
  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unhandled message in Mother: #{inspect(msg)}")
    {:noreply, state}
  end
  
end


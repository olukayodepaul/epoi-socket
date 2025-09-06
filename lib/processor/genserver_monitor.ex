defmodule Application.Monitor do
  use GenServer
  require Logger

  alias DartMessagingServer.DynamicSupervisor
  alias Util.{RegistryHelper}
  alias Storage.{GlobalSubscriberCache, PgDeviceCache, PgDevicesSchema}
  alias Bicp.MonitorAppPresence
  alias Global.StateChange
  alias ApplicationServer.Configuration 

  @force_change_seconds Configuration.server_force_change_seconds()

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
    {:ok, %{eid: eid, current_timer: nil, force_stale: DateTime.utc_now(),  devices: %{}}}
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
    IO.inspect({"LOGIN", device_id})
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
    Logger.warning("Reach by server longin 1 #{device_id}")
    PgDeviceCache.update_status(eid, device_id, "LOGIN", "ONLINE")
    case StateChange.track_state_change(eid) do
      {:changed, user_status, _online_devices} ->
        Logger.warning("Reach by server longin 2 #{device_id}")
        device = PgDeviceCache.get(eid, device_id)
        MonitorAppPresence.broadcast_awareness(device.eid, device.awareness_intention, user_status)
        :ok
      {:unchanged, user_status, _online_devices} ->
        Logger.warning("Reach by server longin 3 #{device_id}")
        IO.inspect({:unchanged, user_status , 1})
        :ok
    end
    # StateChange.cancel_termination_if_all_offline(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_pong, {eid, device_id, status}}, %{force_stale: force_stale} = state) do
    Logger.warning("Reach by server pong 1 #{device_id}")
    now = DateTime.utc_now()
    PgDeviceCache.update_status(eid, device_id, "PONG", "ONLINE")
    case StateChange.track_state_change(eid) do
      {:changed, user_status, _online_devices} ->
        
        Logger.warning("Reach by server pong 2 #{device_id}")
        IO.inspect({:changed, user_status, 3})
        device = PgDeviceCache.get(eid, device_id)
        MonitorAppPresence.broadcast_awareness(device.eid, device.awareness_intention, user_status)
        {:noreply, %{state | force_stale: now}}

      {:unchanged, user_status, _online_devices} ->
        Logger.warning("Reach by server pong 3 #{device_id}")

        idle_too_long? = DateTime.diff(now, force_stale) >= @force_change_seconds

        if idle_too_long? do
            Logger.warning("Reach by server pong 4 #{device_id}")
            device = PgDeviceCache.get(eid, device_id)
            MonitorAppPresence.broadcast_awareness(device.eid, device.awareness_intention, user_status)
            {:noreply, %{state | force_stale: now}}
        else
            {:noreply, state}
        end
    end
  end

  def handle_cast({:monitor_handle_logout, %{device_id: device_id, eid: eid}}, state) do

    PgDeviceCache.delete_only_ets(device_id, eid)

    if StateChange.remaining_active_devices?(eid) do
      IO.inspect(2)
      StateChange.cancel_termination_if_all_offline(state)
    else
      IO.inspect(3)
      StateChange.schedule_termination_if_all_offline(state)
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
    Logger.warning("No activity during grace period. Terminating monitor for #{state.eid}")
    MonitorAppPresence.broadcast_awareness(state.eid, 0, :offline)
    {:stop, :normal, state}
  end

  # Catch-all for unexpected messages
  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unhandled message in Mother: #{inspect(msg)}")
    {:noreply, state}
  end
  
end


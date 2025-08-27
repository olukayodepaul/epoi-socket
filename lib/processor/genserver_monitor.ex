defmodule Application.Monitor do
  use GenServer
  require Logger
  alias DartMessagingServer.DynamicSupervisor
  alias Util.RegistryHelper
  alias App.AllRegistry
  alias Storage.{GlobalSubscriberCache,PgDeviceCache, PgDevicesSchema}
  alias Bicp.MonitorAppPresence 
  
  @moduledoc """
  Mother process for a user. Holds state for devices, messages, etc.
  Survives socket termination.
  """

  @check_interval 5_000      # milliseconds
  # @offline_ttl 15_000        # milliseconds without pong -> offline

  def start_link(eid) do
    GenServer.start(__MODULE__, eid, name: RegistryHelper.via_monitor_registry(eid))
  end

  @impl true
  def init(eid) do
    Logger.info("Monitor init for eid=#{eid}")
    PgDeviceCache.init(eid)
    GlobalSubscriberCache.init(eid)
    # schedule_check()
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
  def handle_cast({:monitor_startup_status, %{eid: eid, device_id: device_id, ws_pid: ws_pid}}, state) do
    case PgDeviceCache.fetch(device_id, eid, ws_pid) do
      {:ok} -> :ok
      {:error} -> 
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        device = %PgDevicesSchema{
          device_id: device_id,
          eid: eid,
          last_seen: now,
          ws_pid: ws_pid |> :erlang.pid_to_list() |> to_string(),
          status: "ONLINE",
          last_received_version: 0,   # initialize version if needed
          ip_address: nil,
          app_version: nil,
          os: nil,
          last_activity: now,
          supports_notifications: true,
          supports_media: true,
          status_source: "system",
          inserted_at: now
        }
        PgDeviceCache.save(device, eid)
    end
    #future scalling. what if the child does not get it. what process are u putting in place to manage that
    AllRegistry.sent_subscriber(device_id, eid, GlobalSubscriberCache.fetch_subscriber_by_owners_eid(eid)) 
    {:noreply, state}
  end

  @impl true
  def handle_cast({:monitor_subscriber_last_seen, %{from: from, to: to, device_id: device_id, status: status}}, state) do
    IO.inspect("mother received #{from} #{to}")
    GlobalSubscriberCache.put_subscribers(to, from, device_id, status)
    {:noreply, state}
  end

  def handle_cast({:monotor_pong_counter, {eid, device_id}}, state) do
    PgDeviceCache.update_status(eid, device_id, "PONG")
    {:noreply, state}
  end

  def handle_cast({:monitor_terminate_child, {eid, device_id}}, state) do

    PgDeviceCache.update_status(eid, device_id, "SYSTEM", "OFFLINE")
    # PgDeviceCache.delete_only_ets(device_id, eid)


    # {:ok, subscribers} = GlobalSubscriberCache.get_all_owner(eid)
    # friends = Enum.map(subscribers, & &1.subscriber_eid)

    # subscription = %Strucs.Awareness{
    #   owner_eid: eid,
    #   device_id: "00000000",
    #   friends: friends,
    #   status: "OFFLINE",
    #   last_seen: DateTime.utc_now() |> DateTime.to_unix()
    # }

    # MonitorAppPresence.broadcast_awareness(subscription)

    # case PgDeviceCache.all_by_owner(eid) do
    #   [] ->
    #     GlobalSubscriberCache.delete(eid)
    #     {:stop, :normal, state}
    #   _ ->
    #     {:noreply, state}
    # end

    {:noreply, state}
  end


  @impl true
  def handle_info(:check_devices, %{eid: eid} = state) do
    IO.inspect("every time session #{eid}")
    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_devices, @check_interval)
  end

end


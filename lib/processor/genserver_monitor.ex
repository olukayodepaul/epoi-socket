defmodule Application.Monitor do
  use GenServer
  require Logger
  alias DartMessagingServer.DynamicSupervisor
  alias Util.RegistryHelper
  alias App.PG.Devices
  alias App.AllRegistry
  alias Storage.GlobalSubscriberCache

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
    App.Device.Cache.init()
    GlobalSubscriberCache.init()
    GlobalSubscriberCache.fetch_all_owner(eid)
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
    #send presence stattus to all the subscriber
    case App.Device.Cache.fetch(device_id, ws_pid) do
      {:ok} -> :ok
      {:error} -> 
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        device = %Devices{
          device_id: device_id,
          eid: eid,
          last_seen: now,
          ws_pid: ws_pid |> :erlang.pid_to_list() |> to_string(),
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
        App.Device.Cache.save(device)
    end
    AllRegistry.sent_subscriber(device_id, eid, GlobalSubscriberCache.get_all_owner(eid)) 
    {:noreply, state}
  end

  @impl true
  def handle_cast({:monitor_terminate_child, {eid, device_id}}, state) do
    App.Device.Cache.delete_only_ets(eid, device_id)
    case App.Device.Cache.all_by_owner(eid) do
      [] ->
        {:stop, :normal, state}
      _ ->
        {:noreply, state}
    end
  end
GlobalSubscriberCache

end



# pid = self()

# # Save pid as string
# pid_str = pid |> :erlang.pid_to_list() |> to_string()
# IO.inspect(pid_str, label: "Stored string")

# # Convert back
# pid_back = pid_str |> String.to_charlist() |> :erlang.list_to_pid()
# IO.inspect(pid_back, label: "Recovered pid")

# IO.puts("Is same? #{pid == pid_back}") 
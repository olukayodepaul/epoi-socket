
defmodule Application.Processor do

  use GenServer
  require Logger

  alias Util.{RegistryHelper, Ping, ConnectSupervisorMonitor}

  def start_link({_eid, device_id, _ws_pid} = state) do
    GenServer.start_link(__MODULE__, state, name: Util.RegistryHelper.via_registry(device_id))
  end
  
  @impl true
  def init({eid, device_id, ws_pid} = _state) do
    RegistryHelper.register(eid, device_id)
    Ping.schedule_ping(device_id)
    handle_start_monitor(device_id)
    {:ok, %{missed_pongs: 0, eid: eid, device_id: device_id, ws_pid: ws_pid}}
  end

  @impl true
  def handle_info(:send_ping, state), do: Ping.handle_ping(state)
  def handle_info(:received_pong, state), do: {:noreply, Ping.reset_pongs(state)}

  def handle_info(:stop_genserver_session, state) do
    Logger.info("Stopping Application.Processor for #{state.device_id}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_cast(:start_monitor, %{eid: eid} = state) do
    IO.inspect(eid, label: "Starting monitor for EID")
    devices = Horde.Registry.lookup(EIdRegistry, eid)

    if length(devices) == 1 do
      Logger.info("First device for #{eid}, starting mother...")
      DartMessagingServer.MonitorDynamicSupervisor.start_mother("useueuhc")
    else
      Logger.debug("Already have #{length(devices)} devices for #{eid}, skipping mother start")
    end
    {:noreply, state}
  end

  def handle_start_monitor(device_id) do
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] ->
        GenServer.cast(pid, :start_monitor)
      [] ->
        Logger.warning("No registry entry for #{device_id}, cannot maybe_start_mother")
    end
  end


end

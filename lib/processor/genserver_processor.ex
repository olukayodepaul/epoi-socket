
defmodule Application.Processor do
  #The GenDServer processor is a delegator

  use GenServer
  require Logger

  alias Util.{RegistryHelper, PingPongHelper, ConnectSupervisorMonitor}
  alias Registries.StartSupervisorMonitor

  def start_link({_eid, device_id, _ws_pid} = state) do
    GenServer.start_link(__MODULE__, state, name: Util.RegistryHelper.via_registry(device_id))
  end
  
  @impl true
  def init({eid, device_id, ws_pid} = _state) do
    RegistryHelper.register(eid, device_id)
    PingPongHelper.schedule_ping(device_id)
    handle_start_monitor(device_id)
    {:ok, %{missed_pongs: 0, eid: eid, device_id: device_id, ws_pid: ws_pid}}
  end

  @impl true
  def handle_info(:send_ping, state), do: PingPongHelper.handle_ping(state)
  def handle_info(:received_pong, state), do: {:noreply, PingPongHelper.reset_pongs(state)}

  # def handle_info(:stop_genserver_session, state) do
  #   #Send message to the parent and ask the parent to stop it self if the eid is 0
  #   Logger.info("Stopping Application.Processor for #{state.device_id}")
  #   StartSupervisorMonitor.terminate_monitor("dnjdddddnjndjdndj")
  #   {:stop, :normal, state}
  # end

  @impl true
  def handle_cast(:start_monitor, %{eid: eid} = state) do
    ConnectSupervisorMonitor.start_supervisor_monitor(eid, "dnjdddddnjndjdndj")
    {:noreply, state}
  end

  def handle_start_monitor(device_id) do
    StartSupervisorMonitor.handle_start_monitor(device_id)
  end

  # @impl true
  # def terminate(_reason, %{eid: _eid} = _state) do
  #   IO.inspect("This is terminate for the child GenServer")
  # end


end

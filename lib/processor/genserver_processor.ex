
defmodule Application.Processor do

  use GenServer
  require Logger

  alias Util.{RegistryHelper, PingPongHelper, ConnectSupervisorMonitor}
  alias Registries.StartSupervisorMonitor
  
  def start_link({_user_id, _eid, device_id, _ws_pid} = state) do
    GenServer.start_link(__MODULE__, state, name: Util.RegistryHelper.via_registry(device_id))
  end
  
  @impl true
  def init({user_id, eid, device_id, ws_pid} = _state) do
    RegistryHelper.register(eid, device_id)
    PingPongHelper.schedule_ping(device_id)
    handle_start_monitor(device_id)
    {:ok, %{missed_pongs: 0, user_id: user_id, eid: eid, device_id: device_id, ws_pid: ws_pid}}
  end

  @impl true
  def handle_info(:send_ping, state), do: PingPongHelper.handle_ping(state)
  def handle_info(:received_pong, state), do: {:noreply, PingPongHelper.reset_pongs(state)}

  @impl true
  def handle_cast(:start_monitor, %{eid: eid, user_id: user_id} = state) do
    ConnectSupervisorMonitor.start_supervisor_monitor(eid, user_id)
    {:noreply, state}
  end

  def handle_cast(:stop_genserver_session , %{user_id: user_id} = state) do
    IO.inspect("GenServer Terminated Pass 4")
    StartSupervisorMonitor.terminate_monitor(%{user_id: user_id})
    {:stop, :normal, state}
  end

  def handle_start_monitor(device_id) do
    StartSupervisorMonitor.handle_start_monitor(device_id)
  end

end
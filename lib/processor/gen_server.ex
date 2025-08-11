defmodule Application.Processor do

  use GenServer
  require Logger

  alias Util.{RegistryHelper, Ping, Ets}

  def start_link({_eid, device_id, _ip, _ws_pid} = state) do
    GenServer.start_link(__MODULE__, state, name: Util.RegistryHelper.via_registry(device_id))
  end
  
  @impl true
  def init({eid, device_id, ip, ws_pid} = _state) do
    RegistryHelper.register(eid, device_id)
    Ping.schedule_ping(device_id)
    Ets.ensure_tables()
    {:ok, %{missed_pongs: 0, eid: eid, device_id: device_id, ip: ip, ws_pid: ws_pid}}
  end

  @impl true
  def handle_info(:send_ping, state), do: Ping.handle_ping(state)
  def handle_info(:received_pong, state), do: {:noreply, Ping.reset_pongs(state)}

  def handle_info(:stop_genserver_session, state) do
    Logger.info("Stopping Application.Processor for #{state.device_id}")
    {:stop, :normal, state}
  end

end

defmodule Application.Processor do

  use GenServer
  require Logger

  def start_link({_eid, device_id, _ip, _ws_pid} = state) do
    GenServer.start_link(__MODULE__, state, name: Util.RegistryHelper.via_registry(device_id))
  end

  def init({eid, device_id, _ip, _ws_pid} = state) do
    Util.RegistryHelper.register(eid, device_id)
    {:ok, state}
  end

end

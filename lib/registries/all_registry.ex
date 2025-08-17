defmodule App.AllRegistry do

  require Logger

  def set_startup_status({eid, device_id, ws_pid}) do
    case Horde.Registry.lookup(UserRegistry, eid) do
      [{pid, _}] ->
        GenServer.cast(pid, {:get_startup_status, %{eid: eid, device_id: device_id, ws_pid: ws_pid }})
      []->
        Logger.warning("No registry entry for #{device_id}, cannot maybe_start_mother")
    end
  end

  def terminate_child_process({eid, device_id}) do
    case Horde.Registry.lookup(UserRegistry, eid) do
    [{pid, _}] ->
      GenServer.cast(pid, {:terminate_child_process, {eid, device_id}})
    [] ->
      Logger.warning("No registry entry for #{device_id}, cannot maybe_start_mother")
    end
  end

end
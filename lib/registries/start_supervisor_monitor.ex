defmodule Registries.StartSupervisorMonitor do

  require Logger

  def handle_start_monitor(device_id) do
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] ->
        GenServer.cast(pid, :start_monitor)
      [] ->
        Logger.warning("No registry entry for #{device_id}, cannot maybe_start_mother")
    end
  end

  def terminate_monitor(user_id, device_id, eid, ws_pid) do
    case Horde.Registry.lookup(UserRegistry, user_id) do
      [{pid, _}] ->
        GenServer.cast(pid, {:stop_monitor, %{user_id: user_id, device_id: device_id, eid: eid, ws_pid: ws_pid}})
      [] ->
        Logger.warning("No registry entry for #{user_id}, cannot stop monitor")
    end
  end

  def terminate_device(user_id, device_id, eid, ws_pid) do
    case Horde.Registry.lookup(DeviceIdRegistry, user_id) do
      [{pid, _}] ->
        GenServer.cast(pid, {:stop_genserver_session, %{user_id: user_id, device_id: device_id, eid: eid, ws_pid: ws_pid}})
      [] ->
        Logger.warning("No registry entry for #{user_id}, cannot stop monitor")
    end
  end

end



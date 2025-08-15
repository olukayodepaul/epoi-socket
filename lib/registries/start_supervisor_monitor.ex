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

  def terminate_monitor(%{eid: eid, user_id: user_id}) do
    IO.inspect("GenServer Terminated Pass 5")
    case Horde.Registry.lookup(UserRegistry, user_id) do
      [{pid, _}] ->
        GenServer.cast(pid, {:stop_monitor, %{eid: eid}})
      [] ->
        Logger.warning("No registry entry for #{user_id}, cannot stop monitor")
    end
  end

  def terminate_device(%{device_id: device_id}) do
    IO.inspect("GenServer Terminated Pass 3")
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] ->
        GenServer.cast(pid, :stop_genserver_session)
      [] ->
        Logger.warning("No registry entry for #{device_id}, cannot stop monitor")
    end
  end

end



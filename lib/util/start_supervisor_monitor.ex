defmodule Util.ConnectSupervisorMonitor do

  require Logger
  alias DartMessagingServer.MonitorDynamicSupervisor

  def start_supervisor_monitor(eid, user_id) do
    devices = Horde.Registry.lookup(EIdDeviceRegistry, eid)
    if length(devices) == 1 do
      Logger.info("First device for #{eid}, starting mother...")
      MonitorDynamicSupervisor.start_mother(user_id)
    end
  end

end
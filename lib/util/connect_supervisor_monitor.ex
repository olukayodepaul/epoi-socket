defmodule Util.ConnectSupervisorMonitor do

  require Logger
  alias DartMessagingServer.MonitorDynamicSupervisor

  def start_supervisor_monitor(eid, user_id) do
    IO.inspect(eid, label: "Starting monitor for EID")
    devices = Horde.Registry.lookup(EIdRegistry, eid)
    if length(devices) == 1 do
      Logger.info("First device for #{eid}, starting mother...")
      MonitorDynamicSupervisor.start_mother(user_id)
    else
      Logger.debug("Already have #{length(devices)} devices for #{eid}, skipping mother start")
    end
  end

  #another function to close the supervisor monitor

end
defmodule Util.ConnectSupervisorMonitor do

  require Logger
  alias DartMessagingServer.MonitorDynamicSupervisor

  def start_supervisor_monitor(user_id) do
    case Horde.Registry.lookup(UserRegistry, user_id) do
      [] ->
        IO.inspect("Mother not running yet, start it")
        MonitorDynamicSupervisor.start_mother(user_id)

      [{pid, _value}] ->
        IO.inspect("Already running, return the PID")
        {:ok, pid}
    end
  end

end
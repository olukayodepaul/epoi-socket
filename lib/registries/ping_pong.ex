defmodule Registries.PingPong do

  require Logger
  alias ApplicationServer.Configuration

  @ping_interval Configuration.ping_interval()

  def schedule_ping_registry(device_id) do
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] -> 
        Process.send_after(pid, :send_ping, @ping_interval)
      [] -> 
        Logger.warning("No registry entry for #{device_id}, cannot schedule ping")
    end
  end

  def handle_pong_registry(device_id) do
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] ->
        Logger.info("Forwarding pong to Application.Processor for #{device_id}")
        send(pid, :received_pong)
      [] ->
        Logger.warning("No Application.Processor GenServer found for pong: #{device_id}")
    end
  end

end
defmodule Util.PingPongHelper do
  require Logger
  
  # alias Util.DisconnectReason
  alias Registries.PingPong
  alias ApplicationServer.Configuration
  alias  App.AllRegistry

  @max_missed_pongs Configuration.max_missed_pongs()

  def handle_ping(%{missed_pongs: missed, eid: eid, device_id: device_id, ws_pid: ws_pid} = state) do
    if missed >= @max_missed_pongs do
      Logger.warning("Missed pong limit reached for #{device_id}, closing connection gracefully")
      AllRegistry.terminate_child_process({eid, device_id})
      {:stop, :normal, state}
    else
      Logger.debug("Sending ping to #{device_id}, missed=#{missed}")
      send(ws_pid, :send_ping)
      schedule_ping(device_id)
      {:noreply, %{state | missed_pongs: missed + 1}}
    end
  end

  def reset_pongs(state) do
    Logger.debug("Pong received, resetting missed_pongs")
    %{state | missed_pongs: 0}
  end

  def schedule_ping(device_id) do
    PingPong.schedule_ping_registry(device_id)
  end


  def handle_pong(device_id, state) do
    Logger.info("Received pong from client: #{device_id}")
    PingPong.handle_pong_registry(device_id)
    {:ok, state}
  end

end
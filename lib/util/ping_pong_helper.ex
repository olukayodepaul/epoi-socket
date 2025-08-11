defmodule Util.Ping do
  require Logger

  @ping_interval 20_000    # Send ping every 20 seconds
  @max_missed_pongs 3 
  alias Util.DisconnectReason

  def handle_ping(%{missed_pongs: missed, eid: _eid, device_id: device_id, ip: _ip, ws_pid: ws_pid} = state) do
    if missed >= @max_missed_pongs do
      Logger.warning("Missed pong limit reached for #{device_id}, closing connection gracefully")
      send(ws_pid, {:send_binary, build_disconnect_message()})
      send(ws_pid, {:close_connection, DisconnectReason.missed_pong()})
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
    case Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] -> 
        Process.send_after(pid, :send_ping, @ping_interval)
      [] -> 
        Logger.warning("No registry entry for #{device_id}, cannot schedule ping")
    end
  end

  defp build_disconnect_message do
    reason = DisconnectReason.missed_pong()
    Jason.encode!(%{type: "disconnect", reason: reason.message})
  end

  def handle_pong(device_id, state) do
    Logger.info("Received pong from client: #{device_id}")

    case Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] ->
        Logger.info("Forwarding pong to CallSession for #{device_id}")
        send(pid, :received_pong)
      [] ->
        Logger.warning("No CallSession GenServer found for pong: #{device_id}")
    end
    {:ok, state}
  end

end

defmodule Util.PingPongHelper do
  require Logger
  
  alias Registries.PingPong
  alias ApplicationServer.Configuration
  alias App.AllRegistry

  @max_missed_pongs Configuration.max_missed_pongs()
  @max_pong_counter Configuration.max_pong_counter()
  @max_allowed_delay Configuration.max_allowed_delay()

  def handle_ping(%{missed_pongs: missed, pong_counter: counter, timer: timer, eid: eid, device_id: device_id, ws_pid: ws_pid} = state) do

      if DateTime.diff(DateTime.utc_now(), timer) > @max_allowed_delay do

        send(ws_pid, :send_ping)
        schedule_ping(device_id)
        AllRegistry.send_pong(device_id, eid) 
        {:noreply, %{state | missed_pongs: O, pong_counter: 0, timer: DateTime.utc_now() }}

      else

        if missed >= @max_missed_pongs do

          Logger.warning("Missed pong limit reached for #{device_id}, closing connection gracefully")
          AllRegistry.send_pong(device_id, eid, "OFFLINE")
          {:noreply, %{state | missed_pongs: O, pong_counter: 0, timer: DateTime.utc_now() }}

        else

          Logger.debug("Sending ping to #{device_id}, missed=#{missed}")
          send(ws_pid, :send_ping)
          schedule_ping(device_id)
          new_counter =
          if counter + 1 >= @max_pong_counter do
            AllRegistry.send_pong(device_id, eid)
            0
          else
            counter + 1
          end
          {:noreply, %{state | missed_pongs: missed + 1, pong_counter: new_counter, timer: DateTime.utc_now() }}

      end
    end
  end

  def reset_pongs(state) do
    Logger.debug("Pong received, resetting missed_pongs")
    %{state | missed_pongs: 0}
  end

  def schedule_ping(device_id) do
    AllRegistry.schedule_ping_registry(device_id)
  end

  def handle_pong(device_id, state) do
    Logger.info("Received pong from client: #{device_id}")
    AllRegistry.handle_pong_registry(device_id)
    {:ok, state}
  end

end

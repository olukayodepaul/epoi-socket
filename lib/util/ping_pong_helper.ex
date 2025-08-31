defmodule Util.PingPongHelper do
  @moduledoc """
  Handles network-level PingPong for child GenServers.
  Tracks missed pongs, round-trip time (RTT), and adapts ping frequency
  and max missed pongs dynamically.
  """

  require Logger
  alias Registries.PingPong
  alias ApplicationServer.Configuration
  alias App.AllRegistry

  @max_pong_counter Configuration.max_pong_counter()
  @default_ping_interval Configuration.default_ping_interval() # ms
  @max_allowed_delay Configuration.max_allowed_delay()         # seconds

  @doc """
  Handles periodic ping logic per device with RTT tracking.
  """
  def handle_ping(%{
        missed_pongs: missed,
        pong_counter: counter,
        timer: last_ping,
        eid: eid,
        device_id: device_id,
        ws_pid: ws_pid,
        last_rtt: last_rtt,
        max_missed_pongs_adaptive: max_missed
      } = state) do

    now = DateTime.utc_now()
    delta = DateTime.diff(now, last_ping)

    cond do
      delta > @max_allowed_delay ->
        force_ping(device_id, ws_pid, eid, state)

      missed >= max_missed ->
        Logger.warning("Missed pong limit reached for #{device_id}, marking offline")
        AllRegistry.send_pong(device_id, eid, "OFFLINE")
        {:noreply, %{state | missed_pongs: 0, pong_counter: 0, timer: now}}

      true ->
        Logger.debug("Sending ping to #{device_id}, missed=#{missed}")
        send(ws_pid, {:send_ping, now})
        schedule_ping(device_id, last_rtt)
        new_counter = increment_counter(counter, device_id, eid)

        {:noreply, %{state | missed_pongs: missed + 1, pong_counter: new_counter, timer: now}}
    end
  end

  defp force_ping(device_id, ws_pid, eid, state) do
    send(ws_pid, {:send_ping, DateTime.utc_now()})
    schedule_ping(device_id, state.last_rtt)
    AllRegistry.send_pong(device_id, eid, "OFFLINE")
    {:noreply, %{state | missed_pongs: 0, pong_counter: 0, timer: DateTime.utc_now()}}
  end

  defp increment_counter(counter, device_id, eid) do
    if counter + 1 >= @max_pong_counter do
      #use the count to send pong to mother server
      AllRegistry.send_pong(device_id, eid)
      0
    else
      counter + 1
    end
  end

  @doc """
  Handle pong from client, calculate RTT and update adaptive values.
  """
  def handle_pong(device_id, sent_time, state) do
    rtt = DateTime.diff(DateTime.utc_now(), sent_time, :millisecond)
    Logger.info("Received pong from #{device_id}, RTT=#{rtt}ms")

    adaptive_interval = calculate_adaptive_interval(rtt)
    adaptive_max_missed = calculate_adaptive_max_missed(rtt)

    AllRegistry.handle_pong_registry(device_id)
    {:ok,
    %{
      state
      | missed_pongs: 0,
        last_rtt: rtt,
        ping_interval: adaptive_interval,
        max_missed_pongs_adaptive: adaptive_max_missed
    }}
  end

  defp calculate_adaptive_interval(rtt) do
    cond do
      rtt > 500 -> 2000   # slow network, ping less often
      rtt < 100 -> 500    # fast network, ping more often
      true -> 1000        # default
    end
  end

  defp calculate_adaptive_max_missed(rtt) do
    cond do
      rtt > 500 -> 8
      rtt < 100 -> 3
      true -> 5
    end
  end

  @doc "Schedule next ping with adaptive interval"
  def schedule_ping(device_id, last_rtt \\ nil) do
    # Determine interval dynamically
    interval =
      if last_rtt do
        calculate_adaptive_interval(last_rtt)
      else
        @default_ping_interval
      end

    # Schedule the ping with the dynamic interval
    AllRegistry.schedule_ping_registry(device_id, interval)
  end

  def reset_pongs(state) do
    now = DateTime.utc_now()
    rtt = DateTime.diff(now, state.timer, :millisecond)

    adaptive_max_missed = calculate_adaptive_max_missed(rtt)

    new_state =
      state
      |> Map.put(:missed_pongs, 0)
      |> Map.update!(:pong_counter, &(&1 + 1))
      |> Map.put(:timer, now)
      |> Map.put(:last_rtt, rtt)
      |> Map.put(:max_missed_pongs_adaptive, adaptive_max_missed)

    {:noreply, new_state}
  end


  
end






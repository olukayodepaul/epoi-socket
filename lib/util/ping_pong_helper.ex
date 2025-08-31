defmodule Util.PingPongHelper do
  @moduledoc """
  Handles network-level PingPong for child GenServers.

  Features:
    - Tracks missed pongs and RTT
    - Adapts ping frequency and max missed pongs dynamically
    - Schedules next ping automatically
  """

  require Logger
  alias ApplicationServer.Configuration
  alias App.AllRegistry

  @max_pong_counter Configuration.max_pong_counter()
  @default_ping_interval Configuration.default_ping_interval() # ms
  @max_allowed_delay Configuration.max_allowed_delay()         # seconds

  @doc """
  Handles periodic ping logic per device with RTT tracking.
  Updates last_send_ping in the state and schedules next ping.
  """
  def handle_ping(state) when is_map(state) do
    missed = Map.get(state, :missed_pongs, 0)
    counter = Map.get(state, :pong_counter, 0)
    last_ping = Map.get(state, :timer, DateTime.utc_now())
    eid = Map.get(state, :eid)
    device_id = Map.get(state, :device_id)
    ws_pid = Map.get(state, :ws_pid)
    last_rtt = Map.get(state, :last_rtt, nil)
    max_missed = Map.get(state, :max_missed_pongs_adaptive, 5)

    now = DateTime.utc_now()
    delta = DateTime.diff(now, last_ping)

    cond do
      delta > @max_allowed_delay ->
        force_ping(device_id, ws_pid, eid, state)

      missed >= max_missed ->

        Logger.warning("Missed pong limit reached for #{device_id}, marking offline #{missed} #{max_missed}")
        {:noreply, %{state | missed_pongs: 0, pong_counter: 0, timer: now, last_rtt: nil}}

      true ->
        send(ws_pid, :send_ping)
        new_counter = increment_counter(counter, device_id, eid)

        {:noreply,
        %{
          state
          | missed_pongs: missed + 1,
            pong_counter: new_counter,
            timer: now,
            last_rtt: last_rtt,
            last_send_ping: now
        }}
    end
  end

  # Force ping and mark device offline
  defp force_ping(device_id, ws_pid, eid, state) do
    send(ws_pid, :send_ping)
    schedule_ping(device_id, Map.get(state, :last_rtt))
    AllRegistry.send_pong(device_id, eid, "OFFLINE")

    {:noreply,
    %{
      state
      | missed_pongs: 0,
        pong_counter: 0,
        timer: DateTime.utc_now(),
        last_send_ping: nil
    }}
  end

  # Increment local pong counter, send notification if limit reached
  defp increment_counter(counter, device_id, eid) do
    if counter + 1 >= @max_pong_counter do
      Logger.debug("Sending ping to Monitor #{eid}, count_down_reset=#{counter}")
      AllRegistry.send_pong(device_id, eid)
      counter_reset = 0
      counter_reset
    else
      counter + 1
    end
  end

  # Adaptive ping interval based on RTT
  defp calculate_adaptive_interval(rtt) do
    cond do
      rtt > 500 -> 2000   # slow network
      rtt < 100 -> 500    # fast network
      true -> 1000        # default
    end
  end

  # Adaptive max missed pongs based on RTT
  defp calculate_adaptive_max_missed(rtt) do
    cond do
      rtt > 500 -> 8
      rtt < 100 -> 3
      true -> 5
    end
  end

  @doc "Schedule next ping with adaptive interval"
  def schedule_ping(device_id, last_rtt \\ nil) do
    interval = last_rtt |> maybe_adaptive_interval()
    AllRegistry.schedule_ping_registry(device_id, interval)
  end

  defp maybe_adaptive_interval(nil), do: @default_ping_interval
  defp maybe_adaptive_interval(rtt), do: calculate_adaptive_interval(rtt)

  @doc """
  Handle pong received from client.
  Calculates RTT from last_send_ping, resets missed_pongs, updates adaptive values,
  and reschedules next ping automatically.
  """
  def pongs_received(device_id, receive_time, state) when is_map(state) do
    last_send_ping = Map.get(state, :last_send_ping)
    rtt = if last_send_ping, do: DateTime.diff(receive_time, last_send_ping, :millisecond), else: 0

    adaptive_max_missed = calculate_adaptive_max_missed(rtt)
    new_counter =
      if Map.get(state, :pong_counter, 0) + 1 >= @max_pong_counter do
        AllRegistry.send_pong(device_id, Map.get(state, :eid))
        0
      else
        Map.get(state, :pong_counter, 0) + 1
      end

    new_state = %{
      state
      | missed_pongs: 0,
        pong_counter: new_counter,
        timer: receive_time,
        last_rtt: rtt,
        max_missed_pongs_adaptive: adaptive_max_missed,
        last_send_ping: receive_time
    }

    # Automatically schedule next ping based on new RTT
    schedule_ping(device_id, rtt)
  
    {:noreply, new_state}
  end

  @doc "Handle pong from network (for socket-level coordination)"
  def handle_pong_from_network(device_id, sent_time) do
    AllRegistry.handle_pong_registry(device_id, sent_time)
  end
  
end

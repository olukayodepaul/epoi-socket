defmodule Util.PingPongHelper do
  @moduledoc """
  Handles network-level PingPong for child GenServers.

  Features:
    - Tracks missed pongs and RTT per device
    - Dynamically adjusts ping frequency and max missed pongs
    - Schedules next ping automatically
    - Integrates with DeviceStateChange to trigger online/offline state updates
  """

  require Logger
  alias ApplicationServer.Configuration
  alias App.AllRegistry
  alias Local.DeviceStateChange

  @max_pong_counter Configuration.max_pong_counter()
  @default_ping_interval Configuration.default_ping_interval() # ms
  @max_allowed_delay Configuration.max_allowed_delay()         # seconds

  @doc """
  Handle periodic ping logic per device.

  - Tracks missed pongs and increments counters
  - Forces offline state if pings delayed or missed
  - Sends ping to client
  - Updates state with last ping time and RTT
  """
  def handle_ping(state) when is_map(state) do
    # Extract state fields
    missed = Map.get(state, :missed_pongs, 0)
    counter = Map.get(state, :pong_counter, 0)
    last_ping = Map.get(state, :timer, DateTime.utc_now())
    eid = Map.get(state, :eid)
    device_id = Map.get(state, :device_id)
    ws_pid = Map.get(state, :ws_pid)
    last_rtt = Map.get(state, :last_rtt, nil)
    max_missed = Map.get(state, :max_missed_pongs_adaptive, 5)

    now = DateTime.utc_now()
    delta = DateTime.diff(now, last_ping) # Time since last ping
    last_state_change = Map.get(state, :last_state_change, DateTime.utc_now()
    )

    cond do
      # Ping is delayed too long → force ping and mark offline
      delta > @max_allowed_delay ->
        Logger.warning("Client0 [#{device_id}] Ping delayed by #{delta}s, forcing ping and marking offline")
        force_ping(device_id, ws_pid, eid, last_state_change, state)

      # Too many missed pongs → mark offline
      missed >= max_missed ->
        Logger.warning("Client0 [#{device_id}] Missed ping limit reached (#{missed}/#{max_missed}), marking offline")
        state_change(device_id, eid, "OFFLINE", last_state_change, state)
        {:noreply, %{state | missed_pongs: 0, pong_counter: 0, timer: now, last_rtt: nil}}

      # Normal case → send ping and increment counters
      true ->
        Logger.info("[Client0 #{device_id}] Sending ping (missed_pongs=#{missed}, counter=#{counter})")
        send(ws_pid, :send_ping)
        new_counter = increment_counter(counter, device_id, eid, last_state_change, state)

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

  # -------------------------
  # Force ping and mark offline
  # -------------------------
  defp force_ping(device_id, ws_pid, eid, last_state_change, state) do
    Logger.warning("[#{device_id}] Forcing ping and marking OFFLINE")
    send(ws_pid, :send_ping)
    # Schedule next ping adaptively
    schedule_ping(device_id, Map.get(state, :last_rtt))
    # Update device state
    state_change(device_id, eid, "OFFLINE", last_state_change, state)

    {:noreply,
    %{
      state
      | missed_pongs: 0,
        pong_counter: 0,
        timer: DateTime.utc_now(),
        last_send_ping: nil
    }}
  end

  # -------------------------
  # Increment local pong counter
  # -------------------------
  defp increment_counter(counter, device_id, eid, last_state_change, state) do
    if counter + 1 >= @max_pong_counter do
      Logger.debug("[#{device_id}] Ping counter limit reached, notifying monitor #{eid}")
      state_change(device_id, eid, "ONLINE", last_state_change, state)
      0
    else
      counter + 1
    end
  end

  # -------------------------
  # Handle device state change
  # -------------------------
  def state_change(device_id, eid, status, last_state_change, state, awareness_intention \\ 2) do
    case DeviceStateChange.track_state_change(
          eid,
          device_id,
          %{
            status: status,
            last_seen: DateTime.utc_now(),
            awareness_intention: awareness_intention,
            last_activity: last_state_change
          }
        ) do
      {:changed, prev_status} -> 
        # Notify registry that device state has changed
        AllRegistry.send_pong_to_server(device_id, eid, prev_status)
        {:noreply, %{state | last_state_change: DateTime.utc_now()}}

      {:refresh, prev_status} ->
        # Forced refresh without state flip
        AllRegistry.send_pong_to_server(device_id, eid, prev_status)
        {:noreply, %{state | last_state_change: DateTime.utc_now()}}

      {:unchanged, curr_status} ->
        # No state change → nothing to do
        {:noreply, state}
    end
  end

  # -------------------------
  # Adaptive interval logic
  # -------------------------
  defp calculate_adaptive_interval(rtt) do
    cond do
      rtt > 500 -> 20_000   # slow network → ping every 2s.. ping 20_000 (ping every 20s)
      rtt < 100 -> 15_00   # fast network → ping every 0.5s... ping 15_000 (15s)
      true -> 1000        # default → ping every 1s
    end
  end

  # Adaptive max missed pongs
  defp calculate_adaptive_max_missed(rtt) do
    cond do
      rtt > 500 -> 8
      rtt < 100 -> 3
      true -> 5
    end
  end

  # -------------------------
  # Schedule next ping
  # -------------------------
  @doc "Schedule next ping with adaptive interval"
  def schedule_ping(device_id, last_rtt \\ nil) do
    interval = last_rtt |> maybe_adaptive_interval()
    Logger.debug("[#{device_id}] Scheduling next ping in #{interval}ms")
    AllRegistry.schedule_ping_registry(device_id, interval)
  end

  defp maybe_adaptive_interval(nil), do: @default_ping_interval
  defp maybe_adaptive_interval(rtt), do: calculate_adaptive_interval(rtt)

  # -------------------------
  # Handle pong received from client
  # -------------------------
  @doc """
  Calculates RTT from last ping, resets missed_pongs, updates adaptive values,
  increments counters, and schedules next ping.
  """
  def pongs_received(device_id, receive_time, state) when is_map(state) do
    last_send_ping = Map.get(state, :last_send_ping)
    rtt = if last_send_ping, do: DateTime.diff(receive_time, last_send_ping, :millisecond), else: 0
    Logger.info("[#{device_id}] Pong received, RTT=#{rtt}ms")

    adaptive_max_missed = calculate_adaptive_max_missed(rtt)
    new_counter =
      if Map.get(state, :pong_counter, 0) + 1 >= @max_pong_counter do
        Logger.debug("[#{device_id}] Pong counter limit reached, sending monitor notification")
        state_change(device_id, Map.get(state, :eid), "ONLINE", Map.get(state, :last_state_change) , state)
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

    Logger.debug("[#{device_id}] Scheduling next ping after pong")
    schedule_ping(device_id, rtt)
  
    {:noreply, new_state}
  end

  # -------------------------
  # Handle pong received from network (WebSocket level)
  # -------------------------
  @doc "Handle pong from network (for socket-level coordination)"
  def handle_pong_from_network(device_id, sent_time) do
    Logger.debug("[#{device_id}] Handling network pong at #{sent_time}")
    AllRegistry.handle_pong_registry(device_id, sent_time)
  end
end

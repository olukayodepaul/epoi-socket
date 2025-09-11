defmodule Global.StateChange do
  @moduledoc """
  Aggregates device statuses into a user-level presence,
  respecting awareness_intention rules and last_seen threshold.

  Rules:
    - awareness_intention = 1 (owner override) => user OFFLINE
    - Otherwise: user ONLINE if any device is ONLINE and within stale threshold
    - Changes are emitted only when:
        * user_status flips, or
        * the set of *online device IDs* changes,
        * or a forced heartbeat triggers if no change for a long time.
  """

  alias Storage.PgDeviceCache
  alias ApplicationServer.Configuration 
  alias App.AllRegistry
  alias QueueSystem
  require Logger

  @stale_threshold_seconds Configuration.server_stale_threshold_seconds() # filter out any device stay longer than this time without update

  # --------- ETS Initialization ---------
  defp state_table_name(eid), do: String.to_atom("global_state_change_#{eid}")

  defp init_state_table(eid) do
    table = state_table_name(eid)
    if :ets.whereis(table) == :undefined do
      :ets.new(table, [:set, :public, :named_table, read_concurrency: true])
    end
    table
  end

  # --------- Internal helpers ---------

  defp user_status_with_devices(owner_eid) do
    now = DateTime.utc_now()
    devices = PgDeviceCache.all(owner_eid)

    owner_override? = Enum.any?(devices, fn d -> d.awareness_intention == 1 end)

    online_devices =
      if owner_override? do
        []
      else
        devices
        |> Enum.filter(fn d ->
          d.status == "ONLINE" and DateTime.diff(now, d.last_seen) <= @stale_threshold_seconds
        end)
        |> Enum.sort_by(& &1.last_seen, {:desc, DateTime})
      end

    user_status =
      cond do
        owner_override? -> :offline
        online_devices != [] -> :online
        true -> :offline
      end

    {user_status, online_devices}
  end

  defp device_ids(devices) do
    devices
    |> Enum.map(& &1.device_id)
    |> Enum.sort()
  end

  defp update_state(table, owner_eid, status, devices, now) do
    :ets.insert(table, {
      owner_eid,
      %{
        user_status: status,
        online_devices: devices,
        last_change_at: now,
        last_seen: now
      }
    })
  end

  defp bump_idle_time(table, owner_eid, prev_state, now) do
    :ets.insert(table, {
      owner_eid,
      %{prev_state | last_seen: now}
    })
  end

  def track_state_change(owner_eid) do
    table = init_state_table(owner_eid)
    now = DateTime.utc_now()
    {user_status, online_devices} = user_status_with_devices(owner_eid)

    case :ets.lookup(table, owner_eid) do
      [] ->
        # First ever state insert
        update_state(table, owner_eid, user_status, online_devices, now)
        {:changed, user_status, online_devices}

      [{^owner_eid, prev_state}] ->
        prev_status = prev_state.user_status
        prev_ids    = device_ids(prev_state.online_devices)
        curr_ids    = device_ids(online_devices)

        cond do
          # (1) Only trigger changed if overall user status flipped
          prev_status != user_status ->
            update_state(table, owner_eid, user_status, online_devices, now)
            {:changed, user_status, online_devices}

          # (2) If still same status, but device set changed → UNCHANGED (just update last_seen)
          user_status == prev_status and prev_ids != curr_ids ->
            bump_idle_time(table, owner_eid, prev_state, now)
            {:unchanged, user_status, online_devices}

          # (4) Nothing significant changed
          true ->
            bump_idle_time(table, owner_eid, prev_state, now)
            {:unchanged, user_status, online_devices}
        end
    end
  end

  def schedule_termination_if_all_offline(%{eid: eid, current_timer: current_timer} = state, intent) do

    now = DateTime.utc_now()
    devices = Storage.PgDeviceCache.all(eid)

    # Filter only ONLINE devices
    online_devices =
      devices
      |> Enum.filter(fn d -> d.status == "ONLINE" end)

    # Cancel previous timer if exists
    if current_timer, do: Process.cancel_timer(current_timer)

    if online_devices == [] do
      # No devices online → use last_seen of last offline device or now
      latest_last_seen =
        devices
        |> Enum.map(& &1.last_seen)
        |> Enum.max(fn -> now end)

      # Adaptive grace period until user would be stale
      diff = DateTime.diff(now, latest_last_seen)
      remaining_seconds = max(@stale_threshold_seconds - diff, 0)
      grace_period_ms = remaining_seconds * 1000

      Logger.warning(
        "All devices offline. Scheduling termination in #{grace_period_ms} ms " <>
        "(stale_threshold: #{@stale_threshold_seconds}s, last_seen diff: #{diff}s)"
      )

      # Schedule termination adaptively
      # timer_ref = Process.send_after(self(), :terminate_process, grace_period_ms)
      timer_ref = Process.send_after(self(), {:terminate_process, intent}, grace_period_ms)
      {:noreply, %{state | current_timer: timer_ref}}
    else
      # At least one device is online → no termination needed
      Logger.info("There are still online devices. No termination scheduled.")
      {:noreply, %{state | current_timer: nil}}
    end
  end

  def cancel_termination_if_all_offline(state) do
    if state.current_timer do
      Process.cancel_timer(state.current_timer)
      Logger.info("Cancelled termination timer for #{state.eid}")
    end
    {:noreply, %{state | current_timer: nil}}
  end

  def remaining_active_devices?(eid) do
    now = DateTime.utc_now()
    benchmark_time = DateTime.add(now, -@stale_threshold_seconds, :second)

    Storage.PgDeviceCache.all(eid)
    |> Enum.filter(fn d ->
      d.status == "ONLINE" and
        case d.last_seen do
          nil -> false
          last_seen -> DateTime.compare(last_seen, benchmark_time) == :gt
        end
    end)
    |> case do
      [] -> false
      _ -> true
    end
  end

  # Process 7
  def monitor_fan_out_relay(eid, data) do
    
    {status, devices} = user_status_with_devices(eid)

    case status do
      :online ->
        Enum.each(devices, fn device ->
          AllRegistry.process_fan_out_relay(device.device_id, data)
        end)

      :offline ->
        Logger.info("User #{eid} is offline, storing in queue")
        QueueSystem.enqueue(nil, nil,  eid , data)
    end
  end

end


# Global.StateChange.schedule_termination_if_all_offline("a@domain.com")

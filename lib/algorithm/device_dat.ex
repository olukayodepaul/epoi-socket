defmodule DevicePresenceAggregator do
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

  @stale_threshold_seconds 60 * 2
  @force_change_seconds 60 * 3   # 5 minutes
  @state_table :device_presence_state

  # --------- ETS Initialization ---------
  def init_state_table do
    if :ets.whereis(@state_table) == :undefined do
      :ets.new(@state_table, [:set, :public, :named_table, read_concurrency: true])
    end
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

  defp update_state(owner_eid, status, devices, now) do
    :ets.insert(@state_table, {
      owner_eid,
      %{
        user_status: status,
        online_devices: devices,
        last_change_at: now,
        last_seen: now
      }
    })
  end

  defp update_last_changed(owner_eid, prev_state, now) do
    :ets.insert(@state_table, {
      owner_eid,
      %{prev_state | last_change_at: now, last_seen: now}
    })
  end

  defp bump_idle_time(owner_eid, prev_state, now) do
    :ets.insert(@state_table, {
      owner_eid,
      %{prev_state | last_seen: now}
    })
  end

  # --------- Public API ---------

  @doc """
  Computes current presence and compares with stored state.

  Returns:
    {:changed, user_status, online_devices} | {:unchanged, user_status, online_devices}

  Change is emitted if the *status* changes, the *device set* changes,
  or the state has been idle longer than `@force_change_seconds`.
  """
  def track_state_change(owner_eid) do
    init_state_table()
    now = DateTime.utc_now()
    {user_status, online_devices} = user_status_with_devices(owner_eid)

    case :ets.lookup(@state_table, owner_eid) do
      [] ->
        # First observation: store and report changed
        update_state(owner_eid, user_status, online_devices, now)
        {:changed, user_status, online_devices}

      [{^owner_eid, prev_state}] ->
        prev_status = prev_state.user_status
        prev_ids    = device_ids(prev_state.online_devices)
        curr_ids    = device_ids(online_devices)

        idle_too_long? = DateTime.diff(now, prev_state.last_change_at) >= @force_change_seconds

        cond do
          # Status flip => changed
          prev_status != user_status ->
            update_state(owner_eid, user_status, online_devices, now)
            {:changed, user_status, online_devices}

          # Same status; if online, only treat as changed if device set changed
          user_status == :online and prev_ids != curr_ids ->
            update_state(owner_eid, user_status, online_devices, now)
            {:changed, user_status, online_devices}

          # Force heartbeat change if idle too long
          idle_too_long? ->
            update_last_changed(owner_eid, prev_state, now)
            {:changed, prev_status, prev_state.online_devices}

          # No real change => bump idle time only
          true ->
            bump_idle_time(owner_eid, prev_state, now)
            {:unchanged, user_status, online_devices}
        end
    end
  end
  
end
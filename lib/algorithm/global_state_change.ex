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

  @stale_threshold_seconds 60 * 2 # filter out any device stay longer than this time without update
  @force_change_seconds 60 * 1   # 3 minutes stay idle for sometime, allow to resent status

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

  defp update_last_changed(table, owner_eid, prev_state, now) do
    :ets.insert(table, {
      owner_eid,
      %{prev_state | last_change_at: now, last_seen: now}
    })
  end

  defp bump_idle_time(table, owner_eid, prev_state, now) do
    :ets.insert(table, {
      owner_eid,
      %{prev_state | last_seen: now}
    })
  end

  # --------- Public API ---------

  def track_state_change(owner_eid) do
    table = init_state_table(owner_eid)
    now = DateTime.utc_now()
    {user_status, online_devices} = user_status_with_devices(owner_eid)

    case :ets.lookup(table, owner_eid) do
      [] ->
        update_state(table, owner_eid, user_status, online_devices, now)
        {:changed, user_status, online_devices}

      [{^owner_eid, prev_state}] ->
        prev_status = prev_state.user_status
        prev_ids    = device_ids(prev_state.online_devices)
        curr_ids    = device_ids(online_devices)

        idle_too_long? = DateTime.diff(now, prev_state.last_change_at) >= @force_change_seconds

        cond do
          prev_status != user_status ->
            update_state(table, owner_eid, user_status, online_devices, now)
            {:changed, user_status, online_devices}

          user_status == :online and prev_ids != curr_ids ->
            update_state(table, owner_eid, user_status, online_devices, now)
            {:changed, user_status, online_devices}

          idle_too_long? ->
            update_last_changed(table, owner_eid, prev_state, now)
            {:changed, prev_status, prev_state.online_devices}

          true ->
            bump_idle_time(table, owner_eid, prev_state, now)
            {:unchanged, user_status, online_devices}
        end
    end
  end
end

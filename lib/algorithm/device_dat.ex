defmodule DevicePresenceAggregator do
  alias Storage.PgDeviceCache

  @stale_threshold_seconds 120
  @state_table :device_presence_state

  # Ensure ETS table exists
  def init_state_table do
    if :ets.whereis(@state_table) == :undefined do
      :ets.new(@state_table, [:set, :public, :named_table, read_concurrency: true])
    end
  end

  defp user_status_with_devices(owner_eid) do
    now = DateTime.utc_now()
    devices = PgDeviceCache.all(owner_eid)

    owner_override? = Enum.any?(devices, fn d -> d.awareness_intention == 1 end)

    online_devices =
      if owner_override? do
        []
      else
        devices
        |> Enum.filter(fn d -> d.status == "ONLINE" and DateTime.diff(now, d.last_seen) <= @stale_threshold_seconds end)
        |> Enum.sort_by(& &1.last_seen, {:desc, DateTime})
      end

    user_status = if owner_override?, do: :offline, else: if(online_devices != [], do: :online, else: :offline)

    {user_status, online_devices}
  end

  # New function to track state changes
  def track_state_change(owner_eid) do
    init_state_table()
    now = DateTime.utc_now()
    {user_status, online_devices} = user_status_with_devices(owner_eid)

    case :ets.lookup(@state_table, owner_eid) do
      [] ->
        # No previous state, insert and return change
        :ets.insert(@state_table, {owner_eid, %{user_status: user_status, online_devices: online_devices, last_seen: now}})
        {:changed, user_status, online_devices}

      [{^owner_eid, prev_state}] ->
        last_seen_expired? =
          Enum.any?(online_devices, fn d ->
            DateTime.diff(now, d.last_seen) > @stale_threshold_seconds
          end)

        if prev_state.user_status != user_status or prev_state.online_devices != online_devices or last_seen_expired? do
          # Update ETS with new state
          :ets.insert(@state_table, {owner_eid, %{user_status: user_status, online_devices: online_devices, last_seen: now}})
          {:changed, user_status, online_devices}
        else
          {:unchanged, user_status, online_devices}
        end
    end
  end
end

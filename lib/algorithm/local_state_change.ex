defmodule Local.DeviceStateChange do
  @moduledoc """
  Tracks state change for a single device.

  Rules:
    - awareness_intention = 1 => device forced OFFLINE
    - Otherwise: device ONLINE if status == "ONLINE" and last_seen within stale threshold
    - Changes emitted only if:
        * device_status flips, OR
        * forced heartbeat triggers after idle too long
  """

  alias App.AllRegistry
  alias ApplicationServer.Configuration
  require Logger

  @stale_threshold_seconds Configuration.client_stale_threshold_seconds()
  @force_change_seconds Configuration.client_force_change_seconds()
  

  # -------- ETS Setup --------
  defp table_name(eid, device_id),
    do: String.to_atom("local_device_state_change_#{eid}_#{device_id}")

  defp init_state_table(eid, device_id) do
    table = table_name(eid, device_id)

    if :ets.whereis(table) == :undefined do
      Logger.info("Created ETS table #{inspect(table)} for #{device_id}/#{eid}")
      :ets.new(table, [:set, :public, :named_table, read_concurrency: true])
    end

    table
  end

  # -------- Public API --------
  @doc """
  Insert or update a device state.
  attrs = %{
    status: "ONLINE" | "OFFLINE",
    last_seen: DateTime,
    awareness_intention: 1 | 2,
    last_activity: DateTime
  }
  """
  def track_state_change(eid, device_id, attrs) do
    table = init_state_table(eid, device_id)
    now = DateTime.utc_now()

    curr_status =
      cond do
        attrs.awareness_intention == 1 ->
          "OFFLINE"

        attrs.status == "ONLINE" and DateTime.diff(now, attrs.last_seen) <= @stale_threshold_seconds ->
          "ONLINE"

        true ->
          "OFFLINE"
      end

    key = :device_state

    case :ets.lookup(table, key) do
      [] ->
        # First insert
        :ets.insert(table, {key, %{
          device_status: curr_status,
          last_change_at: now,
          last_seen: attrs.last_seen,
          last_activity: now
        }})
        Logger.info("Inserted new device state #{curr_status} for #{eid}/#{device_id}")
        {:changed, curr_status}

      [{^key, prev_state}] ->
        prev_status = prev_state.device_status
        idle_too_long? = DateTime.diff(now, prev_state.last_activity) >= @force_change_seconds

        cond do
          prev_status != curr_status ->
            :ets.insert(table, {key, %{
              device_status: curr_status,
              last_change_at: now,
              last_seen: attrs.last_seen,
              last_activity: now
            }})
            Logger.warning("Client Device state changed from #{prev_status} -> #{curr_status} for #{eid}/#{device_id}")
            {:changed, curr_status}

          idle_too_long? ->
            :ets.insert(table, {key, %{prev_state | last_change_at: now, last_seen: attrs.last_seen, last_activity: now}})
            Logger.warning("Client Forced state refresh due to idle timeout for #{eid}/#{device_id} (state: #{curr_status})")
            {:refresh, prev_status}

          true ->
            :ets.insert(table, {key, %{prev_state | last_seen: attrs.last_seen}})
            Logger.warning("Client Device state unchanged for #{eid}/#{device_id} (state: #{curr_status})")
            {:unchanged, curr_status}
        end
    end
  end

  @doc """
  Get the current device state.
  """
  def get(eid, device_id) do
    table = init_state_table(eid, device_id)

    case :ets.lookup(table, :device_state) do
      [{:device_state, record}] ->
        {:ok, record}

      [] ->
        :not_found
    end
  end

  @doc """
  Delete the ETS table for a given device.
  Use when the device is terminated/logged out completely.
  """
  def delete_table(eid, device_id) do
    table = table_name(eid, device_id)

    case :ets.whereis(table) do
      :undefined ->
        Logger.info("No ETS table to delete for #{eid}/#{device_id}")
        :ok

      tid when is_reference(tid) or is_integer(tid) ->
        :ets.delete(table)
        Logger.info("Deleted ETS table #{inspect(table)} for #{eid}/#{device_id}")
        :ok
    end
  end
  
end


# Local.DeviceStateChange.get("a@domain.com","aaaaa1")
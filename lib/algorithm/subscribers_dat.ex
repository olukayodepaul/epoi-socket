defmodule SubscribersAggregatorTunnel do
  @moduledoc """
  Pure functional Device Aggregator Tunnel (DAT).
  Handles subscriber presence, aggregated device lists,
  cleanup, and broadcasting, without using GenServer.
  """

  alias Storage.GlobalSubscriberCache

  @inactivity_threshold_seconds 120  # 1 minute for example

  # ----------------------------
  # Subscriber Management
  # ----------------------------
  @doc """
  Fetch all aggregated subscriber devices for an owner.
  """
  def get_aggregated_subscribers(owner_eid) do
    GlobalSubscriberCache.get_aggregated_subscribers(owner_eid)
  end

  @doc """
  Remove stale devices based on inactivity threshold.
  Updates both device-level and aggregated keys in ETS.
  Returns a map of active subscribers with their active devices.
  """
  def cleanup_stale_devices(owner_eid) do
    now = DateTime.utc_now()
    table = String.to_atom("blobal_subscriber_#{owner_eid}")
    threshold = @inactivity_threshold_seconds

    :ets.foldl(fn {key, record} = entry, acc when is_map(record) ->
      # device-level entry
      if String.starts_with?(key, "awareness#{owner_eid}_") and
        (record.status != "ONLINE" or DateTime.diff(now, record.last_seen) > threshold) do
        :ets.delete(table, key)
      end
      acc

    {key, records} = entry, acc when is_list(records) ->
      # aggregated entry
      if String.starts_with?(key, "awareness#{owner_eid}_") do
        updated =
          Enum.filter(records, fn r ->
            r.status == "ONLINE" and DateTime.diff(now, r.last_seen) <= threshold
          end)

        if updated == [] do
          :ets.delete(table, key)
        else
          :ets.insert(table, {key, updated})
        end
      end
      acc

    _, acc ->
      acc
    end,
    :ok,
    table
    )

    save_stale_records(owner_eid)

    :ok
  end

  # ----------------------------
  # Stale Records Management
  # ----------------------------
  def save_stale_records(owner_eid) do
    stale_table = String.to_atom("stale_subscriber_#{owner_eid}")

    # Create or clear the table
    if :ets.whereis(stale_table) == :undefined do
      :ets.new(stale_table, [:set, :public, :named_table, read_concurrency: true])
    else
      :ets.delete_all_objects(stale_table)
    end

    # Fetch all aggregated devices
    records = get_aggregated_subscribers(owner_eid)

    # Group by subscriber_eid and pick the oldest device for each
    records
    |> Enum.group_by(& &1.subscriber_eid)
    |> Enum.each(fn {subscriber_eid, devices} ->
      oldest_device =
        devices
        |> Enum.min_by(& &1.last_seen)

      # Use a single table and unique key per subscriber
      key = "stale_record_#{owner_eid}_#{subscriber_eid}"
      :ets.insert(stale_table, {key, [oldest_device]})
    end)

    {:ok, :saved}
  end

  def fetch_all_stale_records(owner_eid) do
    stale_table = String.to_atom("stale_subscriber_#{owner_eid}")

    if :ets.whereis(stale_table) == :undefined do
      []
    else
      :ets.tab2list(stale_table)
      |> Enum.flat_map(fn {_key, devices} -> devices end)
    end
  end

  def fetch_stale_record(owner_eid, subscriber_eid) do
    stale_table = String.to_atom("stale_subscriber_#{owner_eid}")
    key = "stale_record_#{owner_eid}_#{subscriber_eid}"

    case :ets.lookup(stale_table, key) do
      [] -> []
      [{^key, devices}] -> devices
    end
  end

  def fetch_stale_list(owner_eid) do

    SubscribersAggregatorTunnel.cleanup_stale_devices(owner_eid)

    stale_table = String.to_atom("stale_subscriber_#{owner_eid}")

    if :ets.whereis(stale_table) == :undefined do
      []
    else
      :ets.tab2list(stale_table)
      |> Enum.flat_map(fn {_key, devices} ->
        Enum.map(devices, & &1.subscriber_eid)
      end)
      |> Enum.uniq()
    end
  end

end


# # SubscribersAggregatorTunnel.fetch_stale_list("a@domain.com")
# # SubscribersAggregatorTunnel.cleanup_stale_devices("a@domain.com")
# # SubscribersAggregatorTunnel.fetch_all_stale_records("a@domain.com")
# # SubscribersAggregatorTunnel.fetch_stale_record("a@domain.com", "b@domain.com")

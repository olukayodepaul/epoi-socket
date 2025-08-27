defmodule DeviceAggregatorTunnel do
  @moduledoc """
  Pure functional Device Aggregator Tunnel (DAT).
  Handles subscriber presence, aggregated device lists,
  cleanup, and broadcasting, without using GenServer.
  """

  alias Storage.GlobalSubscriberCache

  @inactivity_threshold_seconds 60  # 5 minutes

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

    # Fetch all aggregated devices (flat list of maps)
    get_aggregated_subscribers(owner_eid)
    |> Enum.each(fn record ->
      # Remove device if stale
      if DateTime.diff(now, record.last_seen) > @inactivity_threshold_seconds and record.status == "ONLINE" do
        device_key = "awareness#{owner_eid}_#{record.subscriber_eid}_#{record.subscriber_device_id}"
        :ets.delete(table, device_key)
      end
    end)

    # Update aggregated keys after removing stale devices
    :ets.tab2list(table)
    |> Enum.filter(fn {key, value} -> 
      is_binary(key) and
      String.starts_with?(key, "awareness#{owner_eid}_") and
      is_list(value)
    end)
    |> Enum.each(fn {agg_key, records} ->
      updated = Enum.filter(records, fn r ->
        DateTime.diff(now, r.last_seen) <= @inactivity_threshold_seconds
      end)

      if updated == [] do
        :ets.delete(table, agg_key)
      else
        :ets.insert(table, {agg_key, updated})
      end
    end)
    save_stale_records(owner_eid)
    :ok
  end

  def save_stale_records(owner_eid) do
    stale_table = String.to_atom("stale_subscriber_#{owner_eid}")

    # Create table if not exists
    if :ets.whereis(stale_table) == :undefined do
      :ets.new(stale_table, [:set, :public, :named_table, read_concurrency: true])
    else
      # Empty table in one call
      :ets.delete_all_objects(stale_table)
    end

    # Just get the list of records directly
    records = get_aggregated_subscribers(owner_eid)

    # Reduce into grouped map and insert into ETS in one pass
    records
    |> Enum.reduce(%{}, fn record = %{subscriber_eid: subscriber_eid}, acc ->
      Map.update(acc, subscriber_eid, [record], &[record | &1])
    end)
    |> Enum.each(fn {subscriber_eid, devices} ->
      key = "stale_record_#{owner_eid}_#{subscriber_eid}"
      :ets.insert(stale_table, {key, devices})
    end)

    {:ok, :saved}
  end

  def fetch_all_stale_records(owner_eid) do
    stale_table = String.to_atom("stale_subscriber_#{owner_eid}")

    # Return empty list if table doesn't exist
    if :ets.whereis(stale_table) == :undefined do
      []
    else
      :ets.tab2list(stale_table)
      |> Enum.map(fn {_key, devices} -> devices end)
      |> List.flatten()  # flatten so we get a single list of device maps
    end
  end

  def fetch_stale_record(owner_eid, subscriber_eid) do
    stale_table = String.to_atom("stale_subscriber_#{owner_eid}")
    key = "stale_record_#{owner_eid}_#{subscriber_eid}"

    case :ets.lookup(stale_table, key) do
      [] -> []  # no record found
      [{^key, devices}] -> devices
    end
  end

  def fetch_stale_list(owner_eid) do
    stale_table = String.to_atom("stale_subscriber_#{owner_eid}")

    # Return empty list if table doesn't exist
    if :ets.whereis(stale_table) == :undefined do
      []
    else
      :ets.tab2list(stale_table)
      |> Enum.flat_map(fn {_key, devices} ->
        Enum.map(devices, & &1.subscriber_eid)
      end)
      |> Enum.uniq()  # remove duplicates
    end
  end

end
# DeviceAggregatorTunnel.cleanup_stale_devices("a@domain.com")
# DeviceAggregatorTunnel.fetch_stale_records("a@domain.com")
# DeviceAggregatorTunnel.fetch_all_stale_records("a@domain.com")
# DeviceAggregatorTunnel.fetch_stale_list("a@domain.com")
defmodule Storage.GlobalSubscriberCache do
  @moduledoc """
  ETS-based cache for subscribers and device awareness.
  """

  alias Storage.DbDelegator

  # Create ETS table on app start
  def table_name(eid), do: String.to_atom("blobal_subscriber_#{eid}")

  def init(eid) do
    table = table_name(eid)
    if :ets.whereis(table) == :undefined do
      :ets.new(table, [:set, :public, :named_table, read_concurrency: true])
    end
    :ok
  end

  # Fetch subscriber list for owner_eid and cache in ETS
  def fetch_subscriber_by_owners_eid(owner_eid) do
    table = table_name(owner_eid)
    key = "subscriber_list#{owner_eid}"

    case :ets.lookup(table, key) do
      [{^key, subscribers}] ->
        {:ok, subscribers}

      [] ->
        case DbDelegator.all_subscribers_by_user(owner_eid) do
          nil -> {:error, :not_found}
          subscribers when is_list(subscribers) ->
            allowed_subscribers =
              Enum.filter(subscribers, fn s -> Map.get(s, :awareness_status) == "allow" end)

            :ets.insert(table, {key, allowed_subscribers})
            {:ok, allowed_subscribers}
        end
    end
  end

  def put_subscribers(owner_eid, subscriber_eid, subscriber_device_id, status) do

    table = table_name(owner_eid)
    device_key = "awareness#{owner_eid}_#{subscriber_eid}_#{subscriber_device_id}"
    agg_key = "awareness#{owner_eid}_#{subscriber_eid}"

    record = %{
      last_seen: DateTime.utc_now() |> DateTime.truncate(:second),
      owner_eid: owner_eid,
      subscriber_eid: subscriber_eid,
      subscriber_device_id: subscriber_device_id,
      status: status
    }

    # Insert/replace per-device
    :ets.insert(table, {device_key, record})

    # Insert/update aggregated
    case :ets.lookup(table, agg_key) do
      [] ->
        :ets.insert(table, {agg_key, [record]})

      [{^agg_key, records}] ->
        updated =
          [record | Enum.reject(records, fn r -> r.subscriber_device_id == subscriber_device_id end)]

        :ets.insert(table, {agg_key, updated})
    end

    :ok
  end

  def get_subscriber_devices(owner_eid, subscriber_eid) do
    table = table_name(owner_eid)
    case :ets.lookup(table, "awareness#{owner_eid}_#{subscriber_eid}") do
      [] -> []
      [{_key, records}] -> records
    end
  end


  # # Delete ETS table for owner
  # def delete(eid) do
  #   table = table_name(eid)

  #   case :ets.whereis(table) do
  #     :undefined -> :ok
  #     tid when is_reference(tid) -> :ets.delete(table)
  #   end

  #   :ok
  # end
  
end


# Storage.GlobalSubscriberCache.get_subscriber_devices("a@domain.com", "b@domain.com")
# Storage.GlobalSubscriberCache.get_all_subscribers("a@domain.com", "b@domain.com", "bbbbb1")
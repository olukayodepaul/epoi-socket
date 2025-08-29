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

  # # Fetch subscriber list for owner_eid and cache in ETS
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
  
end


# Storage.GlobalSubscriberCache.get_aggregated_subscribers("a@domain.com")
# Storage.GlobalSubscriberCache.fetch_subscriber_by_owners_eid("a@domain.com")
# Storage.GlobalSubscriberCache.get_subscriber_devices("a@domain.com", "b@domain.com")







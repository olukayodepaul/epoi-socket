defmodule Storage.GlobalSubscriberCache do
  @moduledoc """
  ETS-based cache for subscribers. Also syncs to the configured DB via App.Delegator.
  """

  alias App.Storage.Delegator

 
  # Create ETS table on app start

  def table_name(eid), do: String.to_atom("blobal_subscriber_#{eid}")

  def init(eid) do
    table = table_name(eid)
    if :ets.whereis(table) == :undefined do
      :ets.new(table, [:set, :public, :named_table, read_concurrency: true])
    end
    :ok
  end

  # Fetch and cache all subscribers for an owner
  def fetch_all_owner(owner_eid) do
    key = "#{owner_eid}"
    table = table_name(owner_eid)

    case Delegator.all_subscribers_by_user(owner_eid) do
      [] ->
        {:error}
      subscribers ->
        # store whole list under one key
        :ets.insert(table, {key, subscribers})
        {:ok}
    end
  end

  def get_all_owner(owner_eid) do
    key = "#{owner_eid}"
    table = table_name(owner_eid)
    case :ets.lookup(table, key) do
      [{^key, subscribers}] ->
        {:ok, subscribers}
      [] ->
        case Delegator.all_subscribers_by_user(owner_eid) do
          nil ->
            {:error, :not_found}

          subscribers when is_list(subscribers) ->
            # Save in ETS for future lookups
            :ets.insert(table, {key, subscribers})
            {:ok, subscribers}
        end
    end
  end

  def delete(eid) do
    table = table_name(eid)
    case :ets.whereis(table) do
      :undefined -> :ok
      tid when is_reference(tid) -> :ets.delete(table)
    end
    :ok
  end

end


#Testing the data
# Storage.GlobalSubscriberCache.get_all_owner("a@domain.com")


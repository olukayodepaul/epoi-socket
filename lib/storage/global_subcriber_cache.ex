defmodule Storage.GlobalSubscriberCache do
  @moduledoc """
  ETS-based cache for subscribers. Also syncs to the configured DB via App.Delegator.
  """

  alias App.Storage.Delegator

  @subscriber_table :subscriber_cache

  # Create ETS table on app start
  def init do
    if :ets.whereis(@subscriber_table) == :undefined do
      :ets.new(@subscriber_table, [:set, :public, :named_table, read_concurrency: true])
    end
    :ok
  end

  # Fetch and cache all subscribers for an owner
  def fetch_all_owner(owner_eid) do
    key = "#{owner_eid}"

    case Delegator.all_subscribers_by_user(owner_eid) do
      [] ->
        {:error}

      subscribers ->
        # store whole list under one key
        :ets.insert(@subscriber_table, {key, subscribers})
        {:ok}
    end
  end

  def get_all_owner(owner_eid) do
    key = "#{owner_eid}"

    case :ets.lookup(@subscriber_table, key) do
      [{^key, subscribers}] ->
        {:ok, subscribers}

      [] ->
        case Delegator.all_subscribers_by_user(owner_eid) do
          nil ->
            {:error, :not_found}

          subscribers when is_list(subscribers) ->
            # Save in ETS for future lookups
            :ets.insert(@subscriber_table, {key, subscribers})
            {:ok, subscribers}
        end
    end
  end

end


#Testing the data
# Storage.GlobalSubscriberCache.get_all_owner("a@domain.com")


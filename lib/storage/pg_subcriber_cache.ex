defmodule App.Subscriber.Cache do
  @moduledoc """
  ETS-based cache for subscribers. Also syncs to the configured DB via App.Delegator.
  """

  alias App.PG.Subscriber
  alias App.Storage.Delegator

  @subscriber_table :subscriber_cache

  # Create ETS table on app start
  def init do
    if :ets.whereis(@subscriber_table) == :undefined do
      :ets.new(@subscriber_table, [:set, :public, :named_table, read_concurrency: true])
    end
    :ok
  end

  # Insert a subscriber into ETS and persist asynchronously
  def save(%Subscriber{} = subscriber) do
    key = "#{subscriber.owner_eid}:#{subscriber.subscriber_eid}"
    :ets.insert(@subscriber_table, {key, subscriber})
    Task.start(fn -> Delegator.save_subscriber(subscriber) end)
    :ok
  end

  # Fetch subscriber from ETS, fallback to DB if missing
  def fetch(owner_eid, subscriber_eid) do
    key = "#{owner_eid}:#{subscriber_eid}"

    case :ets.lookup(@subscriber_table, key) do
      [{^key, subscriber}] ->
        {:ok, subscriber}

      [] ->
        case Delegator.get_subscriber(subscriber_eid) do
          nil -> {:error, :not_found}
          subscriber ->
            :ets.insert(@subscriber_table, {key, subscriber})
            {:ok, subscriber}
        end
    end
  end

  # Get subscriber from ETS only
  def get(owner_eid, subscriber_eid) do
    key = "#{owner_eid}:#{subscriber_eid}"

    case :ets.lookup(@subscriber_table, key) do
      [{^key, subscriber}] -> subscriber
      [] -> nil
    end
  end

  # Delete subscriber from ETS and DB
  def delete(owner_eid, subscriber_eid) do
    key = "#{owner_eid}:#{subscriber_eid}"
    :ets.delete(@subscriber_table, key)
    Delegator.delete_subscriber(subscriber_eid)
  end

  # Delete subscriber only from ETS
  def delete_only_ets(owner_eid, subscriber_eid) do
    key = "#{owner_eid}:#{subscriber_eid}"
    :ets.delete(@subscriber_table, key)
  end

  # List all subscribers in ETS
  def all do
    :ets.tab2list(@subscriber_table)
    |> Enum.map(fn {_key, subscriber} -> subscriber end)
  end

  # List subscribers by owner
  def all_by_owner(owner_eid) do
    :ets.tab2list(@subscriber_table)
    |> Enum.map(fn {_key, subscriber} -> subscriber end)
    |> Enum.filter(&(&1.owner_eid == owner_eid))
  end

  # Update subscriber status
  def update_status(owner_eid, subscriber_eid, status) do
    update_subscriber_field(owner_eid, subscriber_eid, :status, status)
  end

  defp update_subscriber_field(owner_eid, subscriber_eid, field, value) do
    key = "#{owner_eid}:#{subscriber_eid}"

    case :ets.lookup(@subscriber_table, key) do
      [{^key, subscriber}] ->
        updated_subscriber = Map.put(subscriber, field, value)
        Delegator.save_subscriber(updated_subscriber)
        :ets.insert(@subscriber_table, {key, updated_subscriber})
        {:ok, updated_subscriber}

      [] ->
        {:error, :not_found}
    end
  end

  # Fetch all subscribers for owner from DB and cache in ETS
  def fetch_and_cache_by_owner(owner_eid) do
    subscribers = Delegator.get_all_subscribers_by_owner(owner_eid)

    Enum.each(subscribers, fn subscriber ->
      key = "#{subscriber.owner_eid}:#{subscriber.subscriber_eid}"
      :ets.insert(@subscriber_table, {key, subscriber})
    end)

    {:ok, subscribers}
  end
end

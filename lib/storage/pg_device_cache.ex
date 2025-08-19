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
    :ets.insert(@subscriber_table, {ets_key(subscriber), subscriber})
    Task.start(fn -> Delegator.save_subscriber(subscriber) end)
    :ok
  end

  # Fetch subscriber from ETS, fallback to DB if missing
  def fetch(owner_eid, subscriber_eid) do
    key = ets_key(owner_eid, subscriber_eid)

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
    key = ets_key(owner_eid, subscriber_eid)

    case :ets.lookup(@subscriber_table, key) do
      [{^key, subscriber}] -> subscriber
      [] -> nil
    end
  end

  # Delete subscriber
  def delete(owner_eid, subscriber_eid) do
    key = ets_key(owner_eid, subscriber_eid)
    :ets.delete(@subscriber_table, key)
    Delegator.delete_subscriber(subscriber_eid)
  end

  def delete_only_ets(owner_eid, subscriber_eid) do
    :ets.delete(@subscriber_table, ets_key(owner_eid, subscriber_eid))
  end

  # List all subscribers in ETS
  def all do
    :ets.tab2list(@subscriber_table)
    |> Enum.map(fn {_key, subscriber} -> subscriber end)
  end

  # List subscribers by owner
  def all_by_owner(owner_eid) do
    all()
    |> Enum.filter(&(&1.owner_eid == owner_eid))
  end

  # Update subscriber status
  def update_status(owner_eid, subscriber_eid, status) do
    update_subscriber_field(owner_eid, subscriber_eid, :status, status)
  end

  # Generic update for any field
  defp update_subscriber_field(owner_eid, subscriber_eid, field, value) do
    key = ets_key(owner_eid, subscriber_eid)

    case :ets.lookup(@subscriber_table, key) do
      [{^key, subscriber}] ->
        updated = Map.put(subscriber, field, value)
        Delegator.save_subscriber(updated)
        :ets.insert(@subscriber_table, {key, updated})
        {:ok, updated}

      [] ->
        {:error, :not_found}
    end
  end

  # Helper to build ETS key
  defp ets_key(%Subscriber{owner_eid: owner, subscriber_eid: sub}), do: "#{owner}:#{sub}"
  defp ets_key(owner_eid, subscriber_eid), do: "#{owner_eid}:#{subscriber_eid}"
end

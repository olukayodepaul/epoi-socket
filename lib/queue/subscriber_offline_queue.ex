defmodule OfflineQueue do

  @table :offline_subscriptions

  # Add a pending subscription request
  def enqueue(subscription_id, from_eid, to_eid, payload) do
    :mnesia.transaction(fn ->
      :mnesia.write({@table, subscription_id, from_eid, to_eid, payload, System.system_time(:millisecond)})
    end)
    :ok
  end

  # Fetch all pending requests for a specific user
  def fetch(to_eid) do
    {:atomic, results} =
      :mnesia.transaction(fn ->
        case :mnesia.index_read(:offline_subscriptions, to_eid, :to_eid) do
          [] -> []
          rows -> rows
        end
      end)

    results
  end

  # Fetch and delete (deliver then cleanup)
  def fetch_and_delete(to_eid) do
    {:atomic, results} =
      :mnesia.transaction(fn ->
        rows = :mnesia.index_read(:offline_subscriptions, to_eid, :to_eid)

        Enum.each(rows, fn {_, subscription_id, _, _, _, _} ->
          :mnesia.delete({:offline_subscriptions, subscription_id})
        end)

        rows
      end)

    results
  end

  # Flush all entries from the table
  def flush_all do
    :mnesia.transaction(fn ->
      :mnesia.foldl(
        fn record, _acc ->
          :mnesia.delete({@table, elem(record, 1)}) # elem(record, 1) = subscription_id
          :ok
        end,
        :ok,
        @table
      )
    end)
  end


end
# OfflineQueue.fetch("b@domain.com")
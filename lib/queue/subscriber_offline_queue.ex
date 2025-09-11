defmodule QueueSystem do

  @table :offline_subscriptions
  alias Global.StateChange
  

  # Add a pending subscription request
  def enqueue(subscription_id, from_eid, to_eid, payload, id \\ :offline) do
    # unique composite key: {type, subscription_id, to_eid}

    :mnesia.transaction(fn ->
      :mnesia.write({@table, id, subscription_id, from_eid, to_eid, payload, System.system_time(:millisecond)})
    end)

    :ok
  end

  # Fetch all pending requests for a specific user
  def fetch_by_id(id) do
    {:atomic, result} =
      :mnesia.transaction(fn ->
        :mnesia.match_object({@table, id, :_, :_, :_, :_, :_})
      end)
    result
  end

  # Fetch and delete (deliver then cleanup)
  def fetch_and_delete(id, to_eid) do
    {:atomic, results} =
      :mnesia.transaction(fn ->
        rows = :mnesia.index_read(@table, to_eid, :to_eid)

        filtered =
          Enum.filter(rows, fn {@table, row_id, _, _, row_to_eid, _, _} -> row_id == id and row_to_eid == to_eid
          end)

        Enum.each(filtered, fn {@table, row_id, _, _, _, _, _} ->
          :mnesia.delete({@table, row_id})
        end)

        filtered
      end)

    results
  end

  # Flush all entries from the table
  def flush_all do
    :mnesia.transaction(fn ->
      :mnesia.foldl(
        fn record, _acc ->
          id = elem(record, 1)  # primary key
          :mnesia.delete({@table, id})
          :ok
        end,
        :ok,
        @table
      )
    end)
  end

  def fetch_all do
    {:atomic, results} =
      :mnesia.transaction(fn ->
        :mnesia.match_object({:offline_subscriptions, :_, :_, :_, :_, :_, :_})
      end)

    results
  end

  # Check if a record exists by id, subscription_id and from_eid
  def exists?(id, subscription_id, from_eid) do
    {:atomic, result} =
      :mnesia.transaction(fn ->
        :mnesia.match_object({@table, id, subscription_id, from_eid, :_, :_, :_})
      end)

    result != []
  end

  # Delete by id, subscription_id and from_eid
  def delete(id, subscription_id, from_eid) do
    {:atomic, result} =
      :mnesia.transaction(fn ->
        matches = :mnesia.match_object({@table, id, subscription_id, from_eid, :_, :_, :_})

        Enum.each(matches, fn record ->
          :mnesia.delete_object(record)   # ✅ delete the full record
        end)

        matches
      end)

    result != []
  end

  def fanout_results(id, to_eid) do
    results = fetch_and_delete(id, to_eid)

    Enum.each(results, fn
      {@table, _row_id, _from, _owner_eid, _to_eid, payload, _ts} ->
        IO.inspect({id, to_eid, payload})
        StateChange.monitor_fan_out_relay(to_eid, payload)
    end)
    :ok
  end
  

end
# QueueSystem.fetch_all()
# QueueSystem.flush_all()
# Storage.PgDeviceCache.all("d@domain.com")
# {:offline_subscriptions, id, subscription_id, from_eid, to_eid, payload, timestamp}
#  OfflineQueue.exists?(:sub, "ancisdcsad", "a@domain.com")
# :mnesia.table_info(:offline_subscriptions, :attributes)
# :mnesia.table_info(:offline_subscriptions, :type)
# :mnesia.table_info(:offline_subscriptions, :index)
# :mnesia.table_info(:offline_subscriptions, :disc_copies)
# :mnesia.table_info(:offline_subscriptions, :size)

#:mnesia.stop()
#:mnesia.start()


# # 1️⃣ Stop Mnesia first (optional but safe)
# :ok = :mnesia.stop()

# # 2️⃣ Delete the existing table
# case :mnesia.delete_table(:offline_subscriptions) do
#   {:atomic, :ok} -> IO.puts("✅ Table deleted")
#   {:aborted, reason} -> IO.puts("⚠️ Could not delete table: #{inspect(reason)}")
# end

# # 3️⃣ Start Mnesia again
# :ok = :mnesia.start()

# # 4️⃣ Recreate the table with the correct schema
# :ok =
#   :mnesia.create_table(:offline_subscriptions, [
#     {:attributes, [:id, :subscription_id, :from_eid, :to_eid, :payload, :timestamp]},
#     {:disc_copies, [node()]},
#     {:type, :set},
#     {:index, [:to_eid]}
#   ])
# IO.puts("✅ Table recreated with :id")


# offline_queue insert <type> <subscription_id> <from> <to> <payload>
# offline_queue exists <type> <subscription_id> <from>
# offline_queue delete <type> <subscription_id> <from>
# offline_queue fetch_all
# offline_queue flush

This error is still the same root cause: **your `:offline_subscriptions` table was never created in your Mnesia schema**.

Even though you defined `OfflineQueue`, when you call `enqueue/4` it tries to write into a table that does not exist yet.

---

### ✅ Fix path (step by step)

1. **Stop Mnesia completely**:

```elixir
:mnesia.stop()
```

2. **Create schema (only once per project/node name)**:

```elixir
:mnesia.create_schema([node()])
```

3. **Start Mnesia**:

```elixir
:mnesia.start()
```

4. **Create the table**:

```elixir
:mnesia.create_table(:offline_subscriptions, [
  {:attributes, [:subscription_id, :from_eid, :to_eid, :payload, :timestamp]},
  {:disc_copies, [node()]},
  {:type, :set},
  {:index, [:to_eid]}
])
```

You should see:

```elixir
{:atomic, :ok}
```

5. **Verify**:

```elixir
:mnesia.table_info(:offline_subscriptions, :attributes)
```

You should now get:

```elixir
[:subscription_id, :from_eid, :to_eid, :payload, :timestamp]
```

---

### ⚡ Important

- You only need to do steps **2–4 once** for your node name. After that, the table exists on disk and will be reloaded every time `:mnesia.start()` runs.
- Right now, your crash happens because the `create_table` step never succeeded (or schema wasn’t created).

OfflineQueue.enqueue("sub-123", "a@domain.com", "b@domain.com", %{msg: "subscribe"})
OfflineQueue.fetch("b@domain.com")

OfflineQueue.fetch_and_delete("b@domain.com")

# returns all subscription requests waiting for B

The GenServ

---

👉 Do you want me to show you how to **embed this setup inside your Application supervisor** so you don’t have to manually run these steps in IEx every time?

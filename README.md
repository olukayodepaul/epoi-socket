## DartMessagingServer

install elixir supervisor project

```js
mix new project-name --sup
```

Look up Registry by eid and device id

```
case lookup_by_device_id("some-device-id") do
  [{pid, _value} | _] ->
    IO.puts("Found process PID: #{inspect(pid)}")
  [] ->
    IO.puts("No process found for device id")
end

case lookup_by_eid(eid) do
  [] ->
    IO.puts("No process found for eid")

  entries ->
    Enum.each(entries, fn {pid, device_id} ->
      IO.puts("Found process PID: #{inspect(pid)} with device_id: #{device_id}")
    end)
end
```

use and create ets

```
# First, ensure ETS table exists
Util.Ets.ensure_tables()

# Insert a revocation record
Util.Ets.store_revocation("device123", "jti_abc123", 1_725_000_000)
# => :ok

# Now check if it's revoked
Util.Ets.revoked?("device123")
# => true

# Check a non-existent device
Util.Ets.revoked?("device999")
# => false

# Clear ETS
:ets.delete_all_objects(:token_revocation)

# Manually insert into Redis only
Redix.command!(:redix, ["HSET", "token_revocation", "device456", Jason.encode!(%{jti: "jti_456", exp: 1_725_000_000})])

# ETS is empty, so this forces it to check Redis
Util.Ets.revoked?("device456")
# => true   (and also syncs into ETS)

# Confirm it's now in ETS too
:ets.lookup(:token_revocation, "device456")

```

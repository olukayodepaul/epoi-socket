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

## Redis

If Redis is running locally:

```
redis-cli
```

If Redis is on another host or a non-default port:

```
redis-cli -h <host> -p <port> -a <password>
```

2️⃣ Check your hash key for revoked tokens

```
HGETALL token_revocation
```

3️⃣ Insert into token revoke to test revoked token manually

```
HSET token_revocation "test-jti-123" '{"jti":"test-jti-123","exp":1723429827}'
```

4️⃣ Check if it exists

```
HEXISTS token_revocation "31dhlam7qgsih94ke40000q1"
```

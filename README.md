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
HSET token_revocation "31dhnp2h4997j94ke40000t1" '{"jti":"31dhnp2h4997j94ke40000t1","exp":1723429827}'
```

4️⃣ Check if it exists

```
HEXISTS token_revocation "31dhlam7qgsih94ke40000q1"
```

### register global registry to manage multiple socket put one registry Horde

install {:horde, "~> 0.8"}

```
{:horde, "~> 0.8"}
```

RUN on each system with domain

```
iex --name server_a@wsone.com --cookie mysecret -S mix
iex --name server_b@wstwo.com --cookie mysecret -S mix
```

set of configuration for the global horde

```
children = [
  {Horde.Registry,name: DeviceIdRegistry, keys: :unique, members: :auto},
  {Horde.Registry, name: EIdRegistry, keys: :unique, members: :auto},
]
```

Connect the nodes (manual, no libcluster)

```
RUN inside each
Node.connect(:"server_a@wsone.com")
Node.connect(:"server_b@wsone.com")
```

## check registry

1️⃣ Check if the registry itself is alive

```
iex> Process.whereis(DeviceIdRegistry)
#PID<0.123.0>   # => registry is running
nil             # => registry is not running
```

2️⃣ Check if a specific device GenServer is registered (individual)

```
iex> Horde.Registry.lookup(DeviceIdRegistry, "abc12s33")
[{#PID<0.320.0>, nil}]   # => the GenServer for this device is running
[]                       # => the GenServer is terminated or not registered
```

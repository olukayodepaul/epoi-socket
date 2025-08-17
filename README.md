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

Horde.Registry.lookup(EIdRegistry, "paul@domain.com")

[{#PID<0.319.0>, "abc1232"}]
[{#PID<0.319.0>, "abc1232"}]

Horde.Registry.lookup(DeviceIdRegistry, "aaaaa")
Horde.Registry.lookup(DeviceIdRegistry, "bbbbb")
Horde.Registry.lookup(DeviceIdRegistry, "ccccc")
Horde.Registry.lookup(UserRegistry, "paul@domain.com")

## creating postgre table

```
CREATE TABLE devices (
    id SERIAL PRIMARY KEY,                 -- auto-increment id
    device_id VARCHAR UNIQUE NOT NULL,     -- unique device identifier
    eid VARCHAR NOT NULL,
    last_seen TIMESTAMP,
    status VARCHAR,
    last_received_version INTEGER,
    ip_address VARCHAR,
    app_version VARCHAR,
    os VARCHAR,
    last_activity TIMESTAMP,
    supports_notifications BOOLEAN DEFAULT FALSE,
    supports_media BOOLEAN DEFAULT FALSE,
    inserted_at TIMESTAMP DEFAULT now()
);

-- Index for querying by user_id
CREATE INDEX devices_eid_index ON devices(eid);
```

## insert into postgrsql table

```
now = DateTime.utc_now() |> DateTime.truncate(:second)

device = %App.Devices.Device{
  device_id: "device_123",
  user_id: "user_001",
  last_seen: now,
  status: "online",
  last_received_version: 1,
  ip_address: "192.168.1.10",
  app_version: "1.0.0",
  os: "iOS",
  last_activity: now,
  supports_notifications: true,
  supports_media: true
}

# Use the unified storage helper
App.Storage.save(device)


App.Storage.get("device_123")
App.Storage.all_by_user("user_001")
```

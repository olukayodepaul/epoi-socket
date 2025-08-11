# Presence Protocol — Quick Review

## Transport

- **Protocol**: WebSocket
- **Encoding**: Protobuf (binary frames)
- **Format**: Raw Protobuf binary (`:binary`), no Base64/JSON in production

---

## Message Schema

```proto
syntax = "proto3";

package presence;

message IndividualPresence {
  string from = 1;       // sender of the presence
  string to = 2;         // intended recipient only
  Type type = 3;         // activity indicator
  int64 timestamp = 4;   // UNIX epoch time (optional)
}

enum Type {
  UNKNOWN = 0;
  TYPING = 1;
  PAUSED = 2;
  RECORDING = 3;
  STOPPED = 4;
  VIEWING = 5;
}
```

---

## Example Flow

### Client

```elixir
presence = %Presence.IndividualPresence{
  from: "alice@example.com",
  to: "bob@example.com",
  type: :TYPING,
  timestamp: System.system_time(:second)
}

binary = Presence.IndividualPresence.encode(presence)
hex = Base.encode16(binary, case: :upper)
IO.inspect(hex)
# send `binary` as WebSocket binary frame
```

### Encoded Payload (hex)

```
0A 11 61 6C 69 63 65 40 65 78 61 6D 70 6C 65 2E 63 6F 6D
12 0F 62 6F 62 40 65 78 61 6D 70 6C 65 2E 63 6F 6D
18 01
20 F2 D4 B9 C4 06
```

---

### Server

```elixir
def websocket_handle({:binary, data}, state) do
  presence = Presence.IndividualPresence.decode(data)
  IO.inspect(presence, label: "Decoded Presence")
  {:ok, state}
end
```

### Decoded Struct

```elixir
%Presence.IndividualPresence{
  from: "alice@example.com",
  to: "bob@example.com",
  type: :TYPING,
  timestamp: 1722617794
}
```

---

## ✅ Advantages

- Compact, efficient, binary‑safe
- Fastest (no Base64/JSON overhead)
- Perfect for real‑time signaling

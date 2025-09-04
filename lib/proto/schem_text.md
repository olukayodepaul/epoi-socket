```awarenesss request

# Create the AwarenessRequest message
request = %Dartmessaging.AwarenessRequest{
  from: %Dartmessaging.Identity{ eid: "a@domain.com" },
  to: %Dartmessaging.Identity{ eid: "b@domain.com" },
  awareness_identifier: System.system_time(:millisecond),
  timestamp: 0
}


# Wrap in MessageScheme
msg_request = %Dartmessaging.MessageScheme{
  route: 4,  # Logical route for awareness_request
  payload: {:awareness_request, request}
}

# Encode to binary for WebSocket
binary_request = Dartmessaging.MessageScheme.encode(msg_request)

# You can now send `binary_request` to your WebSocket
hex = Base.encode16(binary_request, case: :upper)
080422270A0E0A0C6140646F6D61696E2E636F6D120E0A0C6240646F6D61696E2E636F6D18B59EA8E29033


```

```
ping pong


ping_request = %Dartmessaging.PingPong{
  from: %Dartmessaging.Identity{ eid: "a@domain.com",  connection_resource_id  },
  to: %Dartmessaging.Identity{ eid: "b@domain.com" },
  status: 1,                   # 1 = PENDING
  request_time: System.system_time(:millisecond),
  response_time: 0
}

# Wrap in MessageScheme
msg_ping = %Dartmessaging.MessageScheme{
  route: 6,
  payload: {:pingpong_message, ping_request}
}

# Encode to binary
binary_request = Dartmessaging.MessageScheme.encode(msg_ping)

# Optional: hex for debugging
hex_ping = Base.encode16(binary_request, case: :upper)
080632290A0E0A0C6140646F6D61696E2E636F6D120E0A0C6240646F6D61696E2E636F6D200128BBA5A3E29033

```

```

token_revoke_request = %Dartmessaging.TokenRevokeRequest{
  to: %Dartmessaging.Identity{
    eid: "b@domain.com",
    connection_resource_id: "bbbbb1"
  },
  token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",  # raw JWT
  timestamp: System.system_time(:millisecond)
}

# Wrap in MessageScheme
msg_request = %Dartmessaging.MessageScheme{
  route: 7,  # Logical route for TokenRevokeRequest
  payload: {:token_revoke_request, token_revoke_request}
}

# Encode to binary for WebSocket
binary_request = Dartmessaging.MessageScheme.encode(msg_request)

# Optional: convert to hex for debugging/logging
hex_request = Base.encode16(binary_request, case: :upper)

IO.inspect(hex_request, label: "TokenRevokeRequest (hex)")

080632290A0E0A0C6140646F6D61696E2E636F6D120E0A0C6240646F6D61696E2E636F6D200128BBA5A3E29033
```

```logout


logout = %Bimip.Logout{
  to: %Bimip.Identity{
    eid: "a@domain.com",
    connection_resource_id: "aaaaa1",
  },
  type: 1,
  status: 4,
  timestamp: System.system_time(:millisecond)
}

# Wrap in MessageScheme
is_logout = %Bimip.MessageScheme{
  route: 12,  # Logical route for TokenRevokeRequest
  payload: {:logout, logout}
}


binary = Bimip.MessageScheme.encode(is_logout)
hex    = Base.encode16(binary, case: :upper)

080C62230A160A0C6140646F6D61696E2E636F6D12066161616161311001180420AAAAFBA89133
```

```ping_pong

ping_pong = %Bimip.PingPong{
  to: %Bimip.Identity{
    eid: "a@domain.com",
    connection_resource_id: "aaaaa1"
  },
  type: 1,  # 1=PING
  ping_time: System.system_time(:millisecond),
  ping_id: "ergfyerhfjerhguer"
}

# Wrap in MessageScheme
is_ping_pong = %Bimip.MessageScheme{
  route: 6,  # Logical route for TokenRevokeRequest
  payload: {:ping_pong, ping_pong}
}


binary = Bimip.MessageScheme.encode(is_ping_pong)
hex    = Base.encode16(binary, case: :upper)

080632340A160A0C6140646F6D61696E2E636F6D1206616161616131100118F1BB94A191332A116572676679657268666A65726867756572
```

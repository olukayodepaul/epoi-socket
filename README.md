# BIMip (RFC-DRAFT)

**Status:** Draft  
**Category:** Standards Track  
**Author:** Paul Aigokhai Olukayode  
**Created:** 2025-08-30

---

## 1. Introduction

The **Awareness Protocol (AWP)** defines a lightweight message-based system for communicating user and device presence ("awareness") between entities.  
It allows one entity to query the awareness of another, receive responses, and subscribe to notifications about awareness changes.

Awareness information includes:

- Online/offline/busy states
- Last seen timestamp
- Optional geolocation (latitude/longitude)
- Whether awareness was set by the device/network or by explicit user override

---

## 2. Terminology

- **Epohai Identifier (EID):** A unique identifier for a user or device, e.g., `alice@domain.com/phone`
- **Requester:** The entity asking about awareness
- **Responder:** The entity whose awareness is being queried
- **Notification:** A proactive awareness update sent without a request
- **Route:** Logical identifier in the wrapper indicating which payload schema is carried

---

## 3. Protocol Overview

The protocol defines **three primary message types**:

1. **AwarenessRequest** – Sent by a requester to query another entity’s awareness state
2. **AwarenessResponse** – Sent by a responder to return the requested awareness state
3. **AwarenessNotification** – Sent proactively to notify subscribers about awareness changes

Messages are encoded using [Protocol Buffers](https://developers.google.com/protocol-buffers) for compact and interoperable serialization.  
All messages are **wrapped in a `MessageScheme` envelope** that contains a `route` and a `oneof payload`. The route allows the client or server to know which schema to decode.

---

## 4. Message Structures

```proto
syntax = "proto3";
package dartmessaging;

// AwarenessRequest: Query the awareness of another entity
message AwarenessRequest {
  string from = 1;
  string to = 2;
  int64 request_id = 3;
}

// AwarenessResponse: Reply to AwarenessRequest
message AwarenessResponse {
  string from = 1;
  string to = 2;
  int64 request_id = 3;

  AwarenessStatus status = 4;
  int64 last_seen = 5;
  double latitude = 6;
  double longitude = 7;
  int32 awareness_intention = 8; // 1 = device/network, 2 = user override
}

// AwarenessNotification: Push notifications about awareness changes
message AwarenessNotification {
  string from = 1;               // Entity whose awareness changed
  string to = 2;                 // Target entity (EID)
  AwarenessStatus status = 3;    // Current awareness state
  int64 last_seen = 4;           // Unix UTC timestamp
  double latitude = 5;           // Optional: defaults to 0.0 if not set
  double longitude = 6;          // Optional: defaults to 0.0 if not set
  int32 awareness_intention = 7; // Optional: defaults to 0 if not set
}

// AwarenessStatus Enumeration: Standardized awareness states
enum AwarenessStatus {
  STATUS_UNSPECIFIED = 0;
  ONLINE = 1;
  OFFLINE = 2;
  AWAY = 3;
  DND = 4;
  BUSY = 5;
  INVISIBLE = 6;
  NOT_FOUND = 7;
  UNKNOWN = 8;
}

// Standardized error message
message ErrorMessage {
  int32 code = 1;          // Numeric error code (e.g., 400, 404, 500)
  string message = 2;      // Human-readable error description
  string route = 3;        // Optional: which route caused the error
  string details = 4;      // Optional: extra context or debug info
}

// MessageScheme: Envelope for routing multiple schemas
message MessageScheme {
  int64 route = 1;  // Logical route identifier

  oneof payload {
    AwarenessNotification awareness_notification = 2;
    AwarenessResponse awareness_response = 3;
    ErrorMessage error_message = 4;
  }
}
```

### Route numbers (example)

- `1` → AwarenessNotification
- `2` → AwarenessResponse

The client decodes `MessageScheme` first, inspects the `route`, then accesses the correct payload without looping or guessing.

---

## 5. Semantics

### AwarenessRequest

- **MUST** be answered with a corresponding `AwarenessResponse`, unless blocked or unauthorized.

### AwarenessResponse

- **MUST** include the same `request_id` as the original request.
- Provides authoritative awareness state.

### AwarenessNotification

- **MAY** be sent by an entity or server to subscribed parties.
- **MUST NOT** require acknowledgment.

---

## 6. Example Exchanges

### Awareness Notification over WebSocket

```
def handle_cast({:fan_out_to_children, {owner_device_id, eid, awareness}}, state) do
  # Build the AwarenessNotification struct
  notification = %Dartmessaging.AwarenessNotification{
    from: "#{awareness.owner_eid}",
    last_seen: DateTime.to_unix(awareness.last_seen, :second),
    status: awareness.status,
    latitude: awareness.latitude,
    longitude: awareness.longitude,
    awareness_intention: awareness.awareness_intention
  }

  # Wrap in MessageScheme with route
  message = %Dartmessaging.MessageScheme{
    route: 1,  # Route for AwarenessNotification
    payload: {:awareness_notification, notification}
  }

  # Encode into Protobuf binary
  binary = Dartmessaging.MessageScheme.encode(message)

  # Send over WebSocket
  send(state.ws_pid, {:binary, binary})

  {:noreply, state}
end
```

### Client Decoding

```
message = Dartmessaging.MessageScheme.decode(binary)

case message.payload do
  {:awareness_notification, notif} ->
    IO.inspect(notif)

  {:awareness_response, resp} ->
    IO.inspect(resp)

  _ ->
    Logger.error("Unknown route or payload")
end

```

Single decode of `MessageScheme` → inspect `route` → access correct payload.

Works for **one-to-one**, **fan-out**, or **group messages** over a single WebSocket.

---

## 7. Security Considerations

- Authenticate awareness requests to prevent spoofing
- Share sensitive metadata (e.g., location) only with authorized parties
- Rate-limit notifications to prevent flooding

---

## 8. IANA Considerations

- Introduces a new namespace `awareness`; no IANA registry actions required currently

---

## 9. References

- [RFC 6120] "Extensible Messaging and Presence Protocol (XMPP): Core", March 2011
- [RFC 2778] "A Model for Presence and Instant Messaging", February 2000
- [Protocol Buffers Specification](https://developers.google.com/protocol-buffers)

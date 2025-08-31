# BIMip (RFC-DRAFT)

**Status:** Draft  
**Category:** Standards Track  
**Author:** Paul Aigokhai Olukayode  
**Created:** 2025-08-30

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Terminology](#2-terminology)
3. [Protocol Overview](#3-protocol-overview)
4. [Message Types](#4-message-types)
   - [4.1 Awareness Messages](#41-awareness-messages)
   - [4.2 PingPong Messages](#42-pingpong-messages)
5. [Protocol Buffers Definitions](#5-protocol-buffers-definitions)
   - [5.1 Awareness](#51-awareness)
   - [5.2 PingPong](#52-pingpong)
6. [Semantics](#6-semantics)
   - [6.1 Awareness](#61-awareness)
   - [6.2 PingPong](#62-pingpong)
7. [Example Exchanges](#7-example-exchanges)
   - [7.1 Awareness](#71-awareness)
   - [7.2 PingPong](#72-pingpong)
8. [Security Considerations](#8-security-considerations)
9. [IANA Considerations](#9-iana-considerations)
10. [References](#10-references)

---

## 1. Introduction

The Awareness Protocol (AWP) defines a lightweight message-based system for communicating user and device presence ("awareness") between entities.  
It allows one entity to query the awareness of another, receive responses, and subscribe to notifications about awareness changes.

The PingPong Protocol (PPG) provides a standardized mechanism to verify connectivity between two entities, measure latency, and detect lost connections.

Together, they form part of **BIMip (Binary Interface for Messaging & Internet Protocol).**

---

## 2. Terminology

- **Epohai Identifier (EID):** A unique identifier for a user or device, e.g., `alice@domain.com/phone`
- **Requester:** The entity asking about awareness or connectivity
- **Responder:** The entity providing awareness or ping response
- **Notification:** A proactive awareness update sent without a request
- **Route:** Logical identifier in the wrapper indicating which payload schema is carried

---

## 3. Protocol Overview

The protocol defines two categories of primary message types:

### Awareness Messages

- **AwarenessRequest** – Sent by a requester to query another entity’s awareness state
- **AwarenessResponse** – Sent by a responder to return the requested awareness state
- **AwarenessNotification** – Sent proactively to notify subscribers about awareness changes

### PingPong Messages

- **PingPong (REQUEST)** – Sent to check connectivity and measure round-trip latency
- **PingPong (RESPONSE)** – Sent as a reply to indicate success or failure

Messages are encoded using **[Protocol Buffers](https://protobuf.dev/)** or compact and interoperable serialization.  
All messages are wrapped in a `MessageScheme` **envelope** that contains a `route` and a `oneof payload`. The `route` allows the client or server to know which schema to decode without guessing.

---

## 4. Message Types

### 4.1 Awareness Messages

- **AwarenessRequest** – Query awareness state
- **AwarenessResponse** – Return awareness state
- **AwarenessNotification** – Proactive awareness updates

### 4.2 PingPong Messages

- **PingPong (REQUEST)** – Sent to verify connectivity and measure round-trip time
- **PingPong (RESPONSE)** – Sent as a reply to indicate success/failure and timing

---

## 5. Protocol Buffers Definitions

### 5.1 Awareness

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
  double latitude = 5;           // Optional
  double longitude = 6;          // Optional
  int32 awareness_intention = 7; // Optional
}

// AwarenessStatus Enumeration
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
  int32 code = 1;
  string message = 2;
  string route = 3;
  string details = 4;
}
```

### 5.2 PingPong

```java
// PingPong message for connection health
message PingPong {
  string from = 1;          // Sender entity (EID)
  string to = 2;            // Recipient entity (EID)
  PingType type = 3;        // REQUEST = 1, RESPONSE = 2
  PingStatus status = 4;    // UNKNOWN = 0, SUCCESS = 1, FAIL = 2
  int64 request_time = 5;   // Unix UTC timestamp of request (ms)
  int64 response_time = 6;  // Unix UTC timestamp of response (ms)
}

// Ping type
enum PingType {
  REQUEST = 1;
  RESPONSE = 2;
}

// Optional status
enum PingStatus {
  UNKNOWN = 0;
  SUCCESS = 1;
  FAIL = 2;
}

```

### MessageScheme Envelope

```ruby
// Route numbers for MessageScheme:
// 1 -> Logical route identifier (used internally and externally)
// 2 -> AwarenessNotification
// 3 -> AwarenessResponse
// 4 -> AwarenessRequest
// 5 -> ErrorMessage
// 6 -> PingPong

// MessageScheme: Envelope for routing multiple schemas
message MessageScheme {
  int64 route = 1;  // Logical route identifier

  oneof payload {
    AwarenessNotification awareness_notification = 2;
    AwarenessResponse awareness_response = 3;
    AwarenessRequest awareness_request = 4;
    ErrorMessage error_message = 5;
    PingPong pingpong_message = 6;
  }
}

```

---

## 6. Semantics

### 6.1 Awareness

- Requests **MUST** be answered with responses unless blocked/unauthorized.
- Responses **MUST** echo `request_id`.
- Notifications **MAY** be sent proactively without acknowledgment.

### 6.2 PingPong

- A PingPong **REQUEST** is used to test connection health.
- A PingPong **RESPONSE** **MUST** be returned with same timestamps.
- `status` indicates if the connectivity check was successful or failed.

---

## 7. Example Exchanges

### 7.1 Awareness Example

```ruby
def handle_cast({:fan_out_to_children, {owner_device_id, eid, awareness}}, state) do
  notification = %Dartmessaging.AwarenessNotification{
    from: "#{awareness.owner_eid}",
    last_seen: DateTime.to_unix(awareness.last_seen, :second),
    status: awareness.status,
    latitude: awareness.latitude,
    longitude: awareness.longitude,
    awareness_intention: awareness.awareness_intention
  }

  message = %Dartmessaging.MessageScheme{
    route: 1,  # Route for AwarenessNotification
    payload: {:awareness_notification, notification}
  }

  binary = Dartmessaging.MessageScheme.encode(message)
  send(state.ws_pid, {:binary, binary})

  {:noreply, state}
end

```

### 7.2 PingPong Example

```yaml
# Server sends PingPong REQUEST
ping = %Dartmessaging.PingPong{
  from: "server@domain.com",
  to: "client@domain.com",
  type: :REQUEST,
  status: :UNKNOWN,
  request_time: System.system_time(:millisecond)
}

message = %Dartmessaging.MessageScheme{
  route: 10, # Example route for PingPong
  payload: {:pingpong_message, ping}
}

binary = Dartmessaging.MessageScheme.encode(message)
send(state.ws_pid, {:binary, binary})

# Client decodes and replies with RESPONSE
{:pingpong_message, ping_req} ->
  response = %Dartmessaging.PingPong{
    from: ping_req.to,
    to: ping_req.from,
    type: :RESPONSE,
    status: :SUCCESS,
    request_time: ping_req.request_time,
    response_time: System.system_time(:millisecond)
  }

```

---

## 8. Security Considerations

### Transport Security

- All BIMip communications (HTTP/WebSocket) **MUST** use TLS.

### Authentication Architecture

- User login and token issuance are handled by a separate Token Server.
- BIMip servers do **not** generate tokens; they only verify JWT tokens presented by clients.
- Tokens are signed by the Token Server using asymmetric cryptography (private key).
- BIMip servers verify tokens using the built-in public key of the Token Server.

### Token Usage on BIMip

- Clients authenticate by passing the JWT as a Bearer token in the HTTP/WebSocket headers.

**Example header:**

```ruby
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhd...
```

### Token Verification (BIMip Server)

- Validate the signature, expiry, and claims (`device_id`, `eid`) before allowing any message exchange.

### WebSocket Connection Headers Example

```yaml
connection: Upgrade
content-type: application/json
date: Sat, 30 Aug 2025 14:27:00 GMT
sec-websocket-accept: oNrKoJGqQvE9z/886oK2E4gfFVc=
server: Cowboy
upgrade: websocket
x-connection: connected
x-connection_time: 1756564021553
x-host: wsone.com
x-ip: 127.0.0.1
x-message: Successful
x-port: 54115
x-status: 101
x-user_agent: undefined
```

---

## 9. IANA Considerations

- Introduces new namespaces `awareness` and `pingpong`.
- No IANA registry actions required currently.

---

## 10. References

- [RFC 6120] Extensible Messaging and Presence Protocol (XMPP): Core, March 2011
- [RFC 2778] A Model for Presence and Instant Messaging, February 2000
- [Protocol Buffers Specification](https://protobuf.dev/reference/protobuf/proto3-spec/)

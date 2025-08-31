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
   - [4.3 Token Revoke Messages](#43-token-revoke-messages)
5. [Protocol Buffers Definitions](#5-protocol-buffers-definitions)
   - [5.1 Awareness](#51-awareness)
   - [5.2 PingPong](#52-pingpong)
   - [5.3 TokenRevoke](#53-tokenrevoke)
6. [Semantics](#6-semantics)
   - [6.1 Awareness](#61-awareness)
   - [6.2 PingPong](#62-pingpong)
   - [6.3 TokenRevoke](#63-tokenrevoke)
7. [Example Exchanges](#7-example-exchanges)
   - [7.1 Awareness](#71-awareness)
   - [7.2 PingPong](#72-pingpong)
   - [7.3 TokenRevoke](#73-tokenrevoke)
8. [Security Considerations](#8-security-considerations)
9. [IANA Considerations](#9-iana-considerations)
10. [References](#10-references)

---

## 1. Introduction

The Awareness Protocol (AWP) defines a lightweight message-based system for communicating user and device presence ("awareness") between entities.  
It allows one entity to query the awareness of another, receive responses, and subscribe to notifications about awareness changes.

The PingPong Protocol (PPG) provides a standardized mechanism to verify connectivity between two entities, measure latency, and detect lost connections.

The Token Revoke Protocol (TRP) defines a mechanism for logging out specific devices or all devices of a user using JWT-based authentication.

Together, they form part of **BIMip (Binary Interface for Messaging & Internet Protocol).**

---

## 2. Terminology

- **Epohai Identifier (EID):** A unique identifier for a user, e.g., `alice@domain.com`
- **Device EID:** Identifier for a specific device under a user EID
- **Requester:** The entity asking about awareness or connectivity
- **Responder:** The entity providing awareness or ping response
- **Notification:** A proactive awareness update sent without a request
- **Route:** Logical identifier in the wrapper indicating which payload schema is carried

---

## 3. Protocol Overview

The protocol defines three categories of primary message types:

### Awareness Messages

- **AwarenessRequest** – Sent by a requester to query another entity’s awareness state
- **AwarenessResponse** – Sent by a responder to return the requested awareness state
- **AwarenessNotification** – Sent proactively to notify subscribers about awareness changes

### PingPong Messages

- **PingPong (REQUEST)** – Sent to check connectivity and measure round-trip latency
- **PingPong (RESPONSE)** – Sent as a reply to indicate success or failure

### Token Revoke Messages

- **TokenRevoke (REQUEST)** – Sent by client or server to revoke a device or session
- **TokenRevoke (RESPONSE)** – Sent to confirm revocation

Messages are encoded using **[Protocol Buffers](https://protobuf.dev/)** for compact and interoperable serialization.  
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

### 4.3 Token Revoke Messages

- **TokenRevoke (REQUEST)** – Initiates logout for a device or all devices under a user EID
- **TokenRevoke (RESPONSE)** – Confirms revocation

---

## 5. Protocol Buffers Definitions

### 5.1 Awareness

````proto
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


### 5.2 PingPong

```proto
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
````

### 5.3 TokenRevoke

```proto
// Identity with optional device_eid
message Identity {
  string eid = 1;           // User Epohai Identifier
  string device_eid = 2;    // Optional: specific device under the user
}

// Token revoke / logout message
message TokenRevoke {
  Identity from = 1;        // Initiator (user or server)
  Identity to = 2;          // Target entity (user/device)
  RevokeType type = 3;      // REQUEST = 1, RESPONSE = 2
  int64 timestamp = 4;      // Unix UTC timestamp
}

enum RevokeType {
  REQUEST = 1;  // Client initiates logout
  RESPONSE = 2; // Server confirms revocation
}
```

### MessageScheme Envelope

```proto
// Route numbers for MessageScheme:
// 1 -> Logical route identifier
// 2 -> AwarenessNotification
// 3 -> AwarenessResponse
// 4 -> AwarenessRequest
// 5 -> ErrorMessage
// 6 -> PingPong
// 7 -> TokenRevoke

// MessageScheme: Envelope for routing multiple schemas
message MessageScheme {
  int64 route = 1;  // Logical route identifier

  oneof payload {
    AwarenessNotification awareness_notification = 2;
    AwarenessResponse awareness_response = 3;
    AwarenessRequest awareness_request = 4;
    ErrorMessage error_message = 5;
    PingPong pingpong_message = 6;
    TokenRevoke token_revoke = 7;
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

### 6.3 TokenRevoke

- **from:** identifies the initiator of the revoke. Can include `device_eid` if action originates from a specific device.
- **to:** identifies the target user or device. Including `device_eid` targets a specific device; omitting it applies to all devices under the user EID.
- **type:** distinguishes between a **REQUEST** (initiated by client/server) and a **RESPONSE** (confirmation by server).
- **timestamp:** marks when the revoke request or confirmation occurred.
- Servers **MUST** immediately invalidate any revoked sessions and optionally notify other devices.

---

## 7. Example Exchanges

### 7.1 Awareness Example

```elixir
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

```elixir
# Server sends PingPong REQUEST
ping = %Dartmessaging.PingPong{
  from: "server@domain.com",
  to: "client@domain.com",
  type: :REQUEST,
  status: :UNKNOWN,
  request_time: System.system_time(:millisecond)
}

message = %Dartmessaging.MessageScheme{
  route: 6, # Route for PingPong
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

### 7.3 TokenRevoke Example

```elixir
revoke_request = %Dartmessaging.TokenRevoke{
  from: %Dartmessaging.Identity{eid: "admin@domain.com", device_eid: "server1"},
  to: %Dartmessaging.Identity{eid: "user@domain.com", device_eid: "device123"},
  type: :REQUEST,
  timestamp: System.system_time(:millisecond)
}

message = %Dartmessaging.MessageScheme{
  route: 7,
  payload: {:token_revoke, revoke_request}
}

binary = Dartmessaging.MessageScheme.encode(message)
send(state.ws_pid, {:binary, binary})
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

```http
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhd...
```

### Token Verification (BIMip Server)

- Validate the signature, expiry, and claims (`device_eid`, `eid`) before allowing any message exchange.

---

## 9. IANA Considerations

- Introduces new namespaces `awareness`, `pingpong`, `tokenrevoke`.
- No IANA registry actions required currently.

---

## 10. References

- \[RFC 6120] Extensible Messaging and Presence Protocol (XMPP): Core, March 201

defmodule Dartmessaging.AwarenessStatus do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :STATUS_UNSPECIFIED, 0
  field :ONLINE, 1
  field :OFFLINE, 2
  field :AWAY, 3
  field :DND, 4
  field :BUSY, 5
  field :INVISIBLE, 6
  field :NOT_FOUND, 7
  field :UNKNOWN, 8
end

defmodule Dartmessaging.AwarenessRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :from, 1, type: :string
  field :to, 2, type: :string
  field :request_id, 3, type: :int64, json_name: "requestId"
end

defmodule Dartmessaging.AwarenessResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :from, 1, type: :string
  field :to, 2, type: :string
  field :request_id, 3, type: :int64, json_name: "requestId"
  field :status, 4, type: Dartmessaging.AwarenessStatus, enum: true
  field :last_seen, 5, type: :int64, json_name: "lastSeen"
  field :latitude, 6, type: :double
  field :longitude, 7, type: :double
  field :awareness_intention, 8, type: :int32, json_name: "awarenessIntention"
end

defmodule Dartmessaging.AwarenessNotification do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :from, 1, type: :string
  field :to, 2, type: :string
  field :status, 3, type: Dartmessaging.AwarenessStatus, enum: true
  field :last_seen, 4, type: :int64, json_name: "lastSeen"
  field :latitude, 5, type: :double
  field :longitude, 6, type: :double
  field :awareness_intention, 7, type: :int32, json_name: "awarenessIntention"
end

defmodule Dartmessaging.ErrorMessage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :code, 1, type: :int32
  field :message, 2, type: :string
  field :route, 3, type: :string
  field :details, 4, type: :string
end

defmodule Dartmessaging.MessageScheme do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof :payload, 0

  field :route, 1, type: :int64

  field :awareness_notification, 2,
    type: Dartmessaging.AwarenessNotification,
    json_name: "awarenessNotification",
    oneof: 0

  field :awareness_response, 3,
    type: Dartmessaging.AwarenessResponse,
    json_name: "awarenessResponse",
    oneof: 0

  field :error_message, 4, type: Dartmessaging.ErrorMessage, json_name: "errorMessage", oneof: 0
end

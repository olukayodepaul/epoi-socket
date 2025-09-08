defmodule Bimip.Identity do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :eid, 1, type: :string

  field :connection_resource_id, 2,
    proto3_optional: true,
    type: :string,
    json_name: "connectionResourceId"
end

defmodule Bimip.AwarenessNotification do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :from, 1, type: Bimip.Identity
  field :to, 2, type: Bimip.Identity
  field :status, 3, type: :int32
  field :last_seen, 4, type: :int64, json_name: "lastSeen"
  field :latitude, 5, type: :double
  field :longitude, 6, type: :double
  field :awareness_intention, 7, type: :int32, json_name: "awarenessIntention"
end

defmodule Bimip.ErrorMessage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :code, 1, type: :int32
  field :message, 2, type: :string
  field :route, 3, type: :string
  field :details, 4, type: :string
end

defmodule Bimip.Logout do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :to, 1, type: Bimip.Identity
  field :type, 2, type: :int32
  field :status, 3, type: :int32
  field :timestamp, 4, type: :int64
end

defmodule Bimip.PingPong do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :to, 1, type: Bimip.Identity
  field :type, 2, type: :int32
  field :ping_time, 3, type: :int64, json_name: "pingTime"
  field :pong_time, 4, type: :int64, json_name: "pongTime"
  field :ping_id, 5, type: :string, json_name: "pingId"
end

defmodule Bimip.TokenRevokeRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :to, 1, type: Bimip.Identity
  field :token, 2, type: :string
  field :timestamp, 3, type: :int64
  field :reason, 4, type: :string
end

defmodule Bimip.TokenRevokeResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :to, 1, type: Bimip.Identity
  field :status, 2, type: :int32
  field :timestamp, 3, type: :int64
  field :reason, 4, type: :string
end

defmodule Bimip.MessageScheme do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof :payload, 0

  field :route, 1, type: :int64

  field :awareness_notification, 2,
    type: Bimip.AwarenessNotification,
    json_name: "awarenessNotification",
    oneof: 0

  field :ping_pong, 6, type: Bimip.PingPong, json_name: "pingPong", oneof: 0

  field :token_revoke_request, 7,
    type: Bimip.TokenRevokeRequest,
    json_name: "tokenRevokeRequest",
    oneof: 0

  field :token_revoke_response, 8,
    type: Bimip.TokenRevokeResponse,
    json_name: "tokenRevokeResponse",
    oneof: 0

  field :logout, 12, type: Bimip.Logout, oneof: 0
  field :error, 15, type: Bimip.ErrorMessage, oneof: 0
end

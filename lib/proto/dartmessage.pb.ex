defmodule Dartmessaging.AwarenessStatus do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :ONLINE, 0
  field :AWAY, 1
  field :DND, 2
  field :OFFLINE, 3
end

defmodule Dartmessaging.PresenceType do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :TYPING, 0
  field :RECORDING, 1
  field :REACTING, 2
  field :VIEWING, 3
end

defmodule Dartmessaging.Awareness do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :from, 1, type: :string
  field :last_seen, 2, type: :int64, json_name: "lastSeen"
  field :status, 3, type: Dartmessaging.AwarenessStatus, enum: true
  field :latitude, 4, type: :double
  field :longitude, 5, type: :double
end

defmodule Dartmessaging.Presence do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :from, 1, type: :string
  field :to, 2, type: :string
  field :type, 3, type: Dartmessaging.PresenceType, enum: true
  field :timestamp, 4, type: :int64
  field :latitude, 5, type: :double
  field :longitude, 6, type: :double
end

defmodule Dartmessaging.PresenceRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :awareness, 1, type: Dartmessaging.Awareness
  field :presence, 2, type: Dartmessaging.Presence
end

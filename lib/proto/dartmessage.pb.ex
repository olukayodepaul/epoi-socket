defmodule Dartmessaging.MessageStatus do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :PENDING, 0
  field :SENT, 1
  field :DELIVERED, 2
  field :READ, 3
  field :FAILED, 4
end

defmodule Dartmessaging.DartMessage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :id, 1, type: :string
  field :from_eid, 2, type: :string, json_name: "fromEid"
  field :from_device_id, 3, type: :string, json_name: "fromDeviceId"
  field :to_eid, 4, type: :string, json_name: "toEid"
  field :to_device_id, 5, type: :string, json_name: "toDeviceId"
  field :body, 6, type: :string
  field :status, 7, type: Dartmessaging.MessageStatus, enum: true
  field :last_received, 8, type: :uint64, json_name: "lastReceived"
  field :timestamp, 9, type: :int64
end

defmodule Dartmessaging.UserContactList do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :eid, 1, type: :string
  field :device_id, 2, type: :string, json_name: "deviceId"
  field :friends, 3, repeated: true, type: :string
  field :online, 4, type: :bool
  field :last_seen, 5, type: :uint64, json_name: "lastSeen"
end

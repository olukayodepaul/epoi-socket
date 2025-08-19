protoc \
 --proto_path=./priv/protos \
 --elixir_out=plugins=grpc:./lib/proto \
 ./priv/protos/dartmessage.proto

## Testing UserContactList

```
user_contact = %Dartmessaging.UserContactList{
  eid: "user_123",
  device_id: "aaaaa",
  friends: ["friend_1", "friend_2", "friend_3"],
  online: true,
  last_seen: :os.system_time(:millisecond)
}
binary = Dartmessaging.UserContactList.encode(user_contact)
hex = Base.encode16(binary, case: :upper)

```

defmodule Followers.AddSubscribers do
  alias Phoenix.PubSub
  @pubsub ApplicationServer.PubSub
  alias Dartmessaging.UserContactList

  # Subscribe one device to a friend's presence topic
  def add_friend_subscription(%UserContactList{eid: eid, device_id: device_id}, friend_eid) do
    topic = "presence:#{friend_eid}:status"
    :ok = PubSub.subscribe(@pubsub, topic)

    # Track subscription in ETS or other storage if needed
    # :ets.insert(@table, {{eid, device_id}, friend_eid})

    {:ok, %{subscriber: {eid, device_id}, topic: topic}}
  end

  # Subscribe a device to all friends
  def add_friends_subscriptions(%UserContactList{} = user_contact_list) do
    Enum.each(user_contact_list.friends, fn friend_eid ->
      add_friend_subscription(user_contact_list, friend_eid)
    end)
  end

  # Broadcast owner's presence to their own topic
  def broadcast_presence(%UserContactList{eid: eid, device_id: device_id} = user_contact) do
    topic = "presence:#{eid}:status"

    user_presence = %UserContactList{
      eid: eid,
      device_id: device_id,
      friends: user_contact.friends,
      online: user_contact.online,
      last_seen: DateTime.utc_now() |> DateTime.to_unix()
    }

    PubSub.broadcast(@pubsub, topic, {:presence_update, user_presence})
  end
end



# #Subscription format
# %{
#   "eid": "eid_A",
#   "device_id": "A1",
#   "friends": ["eid_B", "eid_C", "eid_D"],
#   "online": false,
#   "last_seen": 1692274550
# }

# %{
#   "eid": "eid_B",
#   "device_id": "1",
#   "friends": [],
#   "online": false,
#   "last_seen": 1692274550
# }
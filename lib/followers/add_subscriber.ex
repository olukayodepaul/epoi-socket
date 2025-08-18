defmodule Followers.AddSubscribers do
  alias Phoenix.PubSub

  @pubsub ApplicationServer.PubSub

  # Track subscriptions in ETS (or in-memory)
  @table :friend_subscriptions
  :ets.new(@table, [:named_table, :set, :public])

  # Subscribe one device to a friend's presence topic
  def add_friend_subscription(%UserContactList{eid: eid, device_id: device_id}, friend_eid) do
    topic = "presence:#{friend_eid}:status"
    :ok = PubSub.subscribe(@pubsub, topic)

    # Track subscription
    :ets.insert(@table, {{eid, device_id}, friend_eid})

    # Broadcast your own presence to this friend
    broadcast_presence(eid, device_id, friend_eid)

    {:ok, %{subscriber: {eid, device_id}, topic: topic}}
  end

  # Subscribe a device to all friends
  def add_friends_subscriptions(%UserContactList{} = user_contact_list) do
    Enum.map(user_contact_list.friends, fn friend_eid ->
      add_friend_subscription(user_contact_list, friend_eid)
    end)
  end

  # Broadcast presence to a specific friend's topic
  def broadcast_presence(eid, device_id, friend_eid) do
    topic = "presence:#{friend_eid}:status"

    user_presence = %UserContactList{
      eid: eid,
      device_id: device_id,
      friends: [],
      online: true,
      last_seen: DateTime.utc_now() |> DateTime.to_unix()
    }

    PubSub.broadcast(@pubsub, topic, {:presence_update, user_presence})
  end

  #Track in the mother GenServer.....
end


# #Subscription format
# %{
#   "eid": "eid_A",
#   "device_id": "A1",
#   "friends": ["eid_B", "eid_C", "eid_D"],
#   "online": false,
#   "last_seen": 1692274550
# }
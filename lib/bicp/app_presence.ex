defmodule Transports.AppPresence do
  alias Phoenix.PubSub
  @pubsub ApplicationServer.PubSub
  alias Model.PresenceSubscription
  require Logger

  def friend_subscription(
        %PresenceSubscription{owner: owner, device_id: device_id},
        friend_eid
      ) do
    topic = "presence:#{friend_eid}:status"

    Logger.info(
      "[Presence] device=#{device_id} owner=#{owner} subscribing to #{topic}"
    )

    :ok = PubSub.subscribe(@pubsub, topic)
    :ok
  end

  # Subscribe a device to all its friends' presence
  def subscriptions(%PresenceSubscription{friends: friends} = data) do
    Enum.each(friends, fn friend_eid ->
      friend_subscription(data, friend_eid)
    end)

    Logger.debug(
      "[Presence] device=#{data.device_id} owner=#{data.owner} subscribed to #{length(friends)} friends"
    )
  end

  # # Broadcast owner's presence to their own topic
  # def broadcast_presence(device_id, eid) do
  #   case :ets.lookup(:presence_table, {device_id, eid}) do
  #     [{{^device_id, ^eid}, user_contact}] ->
  #       topic = "presence:#{eid}:status"

  #       # Construct a fresh presence struct with updated last_seen
  #       user_presence = %PresenceSubscription{
  #         eid: user_contact.eid,
  #         device_id: user_contact.device_id,
  #         friends: user_contact.friends,
  #         online: user_contact.online,
  #         last_seen: DateTime.utc_now() |> DateTime.to_unix()
  #       }

  #       # Broadcast to the user's own topic
  #       PubSub.broadcast(@pubsub, topic, {:presence_update, user_presence})
  #       :ok

  #     [] ->
  #       {:error, :not_found}
  #   end
  # end

end

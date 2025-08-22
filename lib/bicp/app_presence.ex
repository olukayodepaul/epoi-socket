defmodule Bicp.AppPresence do
  alias Phoenix.PubSub
  alias Model.PresenceSubscription
  alias Storage.LocalSubscriberCache
  require Logger

  @pubsub ApplicationServer.PubSub

  @doc """
  Subscribe a device to all its friends' presence and store presence/subscribers in ETS.
  """

  # When user A (socket/GenServer) comes online: 
  # I call AppPresence.subscriptions/1.
  # Inside friend_subscription/2 you do:
  # That means: Owners process is now subscribed to each friend’s presence topic.
  def subscriptions(%PresenceSubscription{device_id: device_id, owner: owner, friends: friends} = data) do
    # Save the subscriber list for this owner
    subs = Enum.map(friends, fn friend_eid -> %{subscriber_eid: friend_eid} end)
    LocalSubscriberCache.subscribers(device_id, owner, subs )

    # Save the owner's full presence in ETS
    LocalSubscriberCache.put(%PresenceSubscription{
      owner: owner,
      device_id: device_id,
      friends: friends,
      online: true,
      typing: false,
      recording: false,
      last_seen: DateTime.utc_now() |> DateTime.to_unix()
    })

    # Subscribe this device to each friend's topic
    Enum.each(friends, fn friend_eid ->
      friend_subscription(data, friend_eid)
    end)

    Logger.debug("[Presence] device=#{device_id} owner=#{owner} subscribed to #{length(friends)} friends")

    # Broadcast owner's presence after saving subscribers and presence
    broadcast_presence(owner, device_id)
  end

  @doc """
  Subscribe a device to a friend's topic.
  """
  def friend_subscription(%PresenceSubscription{owner: owner, device_id: device_id}, friend_eid) do
    topic = "presence:#{friend_eid}:status"
    Logger.info("[Presence] device=#{device_id} owner=#{owner} subscribing to #{topic}")
    :ok = PubSub.subscribe(@pubsub, topic)
    :ok
  end

  @doc """
  Broadcast owner's presence to their own topic.
  """
  # Owner send his own broadcast
  def broadcast_presence(owner, device_id) do
    case LocalSubscriberCache.get_presence(owner, device_id) do
      {:ok, presence} ->
        topic = "presence:#{owner}:status"
        Logger.info("[Presence] Broadcasting owner=#{owner} update to #{topic}")
        Phoenix.PubSub.broadcast(@pubsub, topic, {:presence_update, presence})
        :ok

      {:error, :not_found} ->
        Logger.warning("[Presence] No presence found for owner=#{owner}, cannot broadcast")
        {:error, :no_presence}
    end
  end

  @doc """
  Apply a diff to the owner's presence and immediately broadcast the updated state.
  """
  def apply_diff(owner, device_id, diff) do
    case LocalSubscriberCache.apply_diff(owner, device_id, diff) do
      {:ok, _updated_presence} ->
        broadcast_presence(owner, device_id)

      {:error, :not_found} ->
        Logger.warning("[Presence] Cannot apply diff for owner=#{owner}, presence not found")
        {:error, :no_presence}
    end
  end
  
end

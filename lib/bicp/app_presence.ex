defmodule Bicp.AppPresence do
  @moduledoc """
  Manages subscriptions and broadcasts for user awareness (global) and peer presence.
  """
  alias Phoenix.PubSub
  alias Storage.LocalSubscriberCache
  require Logger

  @pubsub ApplicationServer.PubSub

  # Subscribe a device to all its friends
  def subscriptions(%Strucs.Awareness{owner_eid: owner_eid, device_id: device_id, friends: friends} = awareness) do
    subs = Enum.map(friends, fn friend_eid -> %{subscriber_eid: friend_eid} end)
    LocalSubscriberCache.subscribers(device_id, owner_eid, subs)

    LocalSubscriberCache.put(awareness)

    Enum.each(friends, fn friend_eid ->
      friend_subscription(owner_eid, device_id, friend_eid)
    end)

    Logger.debug("[Awareness] device=#{device_id} owner=#{owner_eid} subscribed to #{length(friends)} friends")
    broadcast_awareness(owner_eid, device_id)
  end

  def friend_subscription(owner_eid, device_id, friend_eid) do
    topic = "presence:#{friend_eid}:status"
    Logger.info("[Awareness] device=#{device_id} owner=#{owner_eid} subscribing to #{topic}")
    :ok = PubSub.subscribe(@pubsub, topic)
    :ok
  end

  def broadcast_awareness(owner_eid, device_id) do
    case LocalSubscriberCache.get_presence(owner_eid, device_id) do
      {:ok, awareness} ->
        topic = "presence:#{owner_eid}:status"
        Logger.info("[Awareness] Broadcasting owner=#{owner_eid} update to #{topic}")
        Phoenix.PubSub.broadcast(@pubsub, topic, {:awareness_update, awareness})
        :ok

      {:error, :not_found} ->
        Logger.warning("[Awareness] No awareness found for owner=#{owner_eid}, cannot broadcast")
        {:error, :no_presence}
    end
  end

  def apply_awareness(%Dartmessaging.Awareness{from: from} = awareness) do

    [owner_eid, device_id] = String.split(from, "/")

    case LocalSubscriberCache.get_presence(owner_eid, device_id) do
      {:ok, existing} ->

        updated = %Strucs.Awareness{
          existing |
          last_seen: awareness.last_seen,
          status: awareness.status,
          latitude: awareness.latitude,
          longitude: awareness.longitude
        }
        LocalSubscriberCache.put(updated)
        broadcast_awareness(owner_eid, device_id)
        :ok
      {:error, :not_found} ->
        Logger.warning("[Awareness] Cannot update, presence not found for #{owner_eid}/#{device_id}")
        {:error, :no_presence}
        :error
    end
  end
  
end

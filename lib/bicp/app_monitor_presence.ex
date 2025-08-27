defmodule Bicp.MonitorAppPresence do
  @moduledoc """
  Manages subscriptions and broadcasts for user awareness (global) and peer presence.
  """
  alias Phoenix.PubSub
  alias ApplicationServer.Configuration 
  require Logger

  @pubsub ApplicationServer.PubSub

  # Subscribe a device to all its friends (one-time)
  def subscriptions(%Strucs.Awareness{owner_eid: owner_eid, device_id: device_id, friends: friends}) do
    Enum.each(friends, fn friend_eid ->
      friend_subscription(owner_eid, device_id, friend_eid)
    end)

    Logger.debug("[Awareness] device=#{device_id} owner=#{owner_eid} subscribed to #{length(friends)} friends")
  end

  defp friend_subscription(owner_eid, device_id, friend_eid) do
    topic = "#{Configuration.awareness_topic()}:#{friend_eid}"
    Logger.info("[Awareness] device=#{device_id} owner=#{owner_eid} subscribing to #{topic}")
    :ok = PubSub.subscribe(@pubsub, topic)
    :ok
  end

  # Broadcast awareness to all friends using the data already in memory
  def broadcast_awareness(%Strucs.Awareness{owner_eid: owner_eid} = awareness) do
    topic = "#{Configuration.awareness_topic()}:#{owner_eid}"
    Logger.info("[Awareness] Broadcasting owner=#{owner_eid} update to #{topic}")

    Phoenix.PubSub.broadcast(@pubsub, topic, {:awareness_update, awareness})
    :ok
  end

end

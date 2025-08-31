defmodule Bicp.MonitorAppPresence do
  @moduledoc """
  Mother-level module for user presence and awareness using dynamic ETS tables per `eid`.

  Handles subscriptions and broadcasts at the `eid` level.
  Each `eid` has its own ETS table storing its friends/subscribers.
  Fetches subscriber/friend list dynamically from `Storage.GlobalSubscriberCache`.
  Each `eid` broadcasts only once; all friends subscribed to this `eid` topic will receive updates.
  """

  alias Phoenix.PubSub
  alias App.AllRegistry
  alias ApplicationServer.Configuration
  alias Storage.PgDeviceCache
  require Logger

  @pubsub ApplicationServer.PubSub

  # ------------------------------
  # Initialize dynamic ETS table for a given owner_eid
  # ------------------------------
  def init_table(owner_eid) do
    table = table_name(owner_eid)

    if :ets.whereis(table) == :undefined do
      :ets.new(table, [:set, :public, :named_table, read_concurrency: true])
    end

    table
  end

  def user_level_subscribtion(eid) do
    topic = "user_level_communication#{eid}"
    PubSub.subscribe(@pubsub, topic)
  end

  def user_level_broadcast(eid, pid, message) do
    topic = "user_level_communication#{eid}"
    Phoenix.PubSub.broadcast(@pubsub, topic, {:direct_communication, message})
  end

  defp table_name(owner_eid) do
    String.to_atom("monitor_app_presence_#{owner_eid}")
  end

  # ------------------------------
  # Subscribe the current owner to all friends' topics
  # ------------------------------
  def subscribe_to_friends(owner_eid) do
    table = init_table(owner_eid)

    friends =
      case :ets.lookup(table, :friends) do
        [{:friends, cached_friends}] -> cached_friends
        [] ->
          fetched = fetch_friends(owner_eid)
          :ets.insert(table, {:friends, fetched})
          fetched
      end

    Enum.each(friends, fn friend_eid ->
      topic = "#{Configuration.awareness_topic()}:#{friend_eid}"
      :ok = PubSub.subscribe(@pubsub, topic)
    end)

    Logger.debug(
      "[Awareness] owner=#{owner_eid} subscribed to #{length(friends)} friends: #{inspect(friends)}"
    )
  end

  # ------------------------------
  # Broadcast the owner's awareness to all subscribers/friends (once per eid)
  # ------------------------------
  def broadcast_awareness(owner_eid, awareness_intention \\ 2, status \\ 1, latitude \\ 0.0 , longitude \\ 0.0) do
    table = init_table(owner_eid)

    friends =
      case :ets.lookup(table, :friends) do
        [{:friends, cached_friends}] -> cached_friends
        [] ->
          fetched = fetch_friends(owner_eid)
          :ets.insert(table, {:friends, fetched})
          fetched
      end

    awareness = %Strucs.Awareness{
      owner_eid: owner_eid,
      friends: friends,
      status: status,
      last_seen: DateTime.utc_now() |> DateTime.truncate(:second),
      latitude: latitude,
      longitude: longitude,
      awareness_intention: awareness_intention
    }

    topic = "#{Configuration.awareness_topic()}:#{owner_eid}"

    Logger.info(
      "[Awareness] Broadcasting owner=#{owner_eid} status=#{awareness.status} to topic=#{topic}"
    )

    # Single broadcast per owner
    :ok = Phoenix.PubSub.broadcast(@pubsub, topic, {:awareness_update, awareness})
    :ok
  end

  # ------------------------------
  # Internal helper to fetch friends/subscribers from DB
  # ------------------------------
  defp fetch_friends(owner_eid) do
    case Storage.GlobalSubscriberCache.fetch_subscriber_by_owners_eid(owner_eid) do
      {:ok, subscribers} ->
        subscribers
        |> Enum.filter(fn s -> s.status == "active" and s.awareness_status == "allow" end)
        |> Enum.map(& &1.subscriber_eid)

      _ -> []
    end
  end

  # ------------------------------
  # Optional: Force refresh friends list from DB and update ETS
  # ------------------------------
  def refresh_friends(owner_eid) do
    table = init_table(owner_eid)
    friends = fetch_friends(owner_eid)
    :ets.insert(table, {:friends, friends})
    friends
  end

  # ------------------------------
  # Fan out awareness to all online child GenServers for this owner
  # ------------------------------
  def fan_out_to_children(owner_eid, %Strucs.Awareness{} = awareness) do
    PgDeviceCache.all(owner_eid)
    |> Enum.filter(fn d -> d.status == "ONLINE" and not is_nil(d.eid) end)
    |> Task.async_stream(
      fn device -> send_to_child(device.device_id, device.eid, awareness) end,
      max_concurrency: 50,
      timeout: 5_000
    )
    |> Stream.run()
  end

  # Send awareness to child GenServer which will relay to socket
  defp send_to_child(device_id, eid, %Strucs.Awareness{} = awareness) do
    AllRegistry.fan_out_to_children(device_id, eid, awareness)
  end


end



How Large-Scale Systems (Like Google's) Handle Presence

The algorithm for a system like Google Chat or Gmail is far more complex than a single function because it has to operate at a massive scale and be resilient to network failures. It's less a simple algorithm and more a set of protocols and a distributed architecture.

The core concepts they use are:

    Heartbeat Mechanism: Instead of a server constantly checking on every client, each device sends a small, periodic heartbeat to the server (e.g., every 30 seconds). This heartbeat tells the server, "I'm still here and active." If the server doesn't receive a heartbeat from a device after a certain timeout period (e.g., 60 seconds), it assumes the device is offline.

    Pub/Sub (Publish-Subscribe): When a user's status changes, the system publishes this event to a central messaging bus. All other clients and services that are "subscribed" to that user's status immediately receive the update. This is much more efficient than having every client constantly poll the server for the status of all their contacts.

    Distributed State and Caching: The "awareness" status isn't stored in a single database. It's a piece of distributed state, meaning it's replicated and cached across many servers and data centers. This ensures that the information is available quickly, is highly reliable, and can handle a massive number of concurrent requests.

In short, while your function is perfect for a local, on-demand check, a system like Google's uses a combination of network protocols, real-time messaging, and distributed databases to manage presence information at a global scale.

Yes, you absolutely can.

Using a client's "pong" response to a server's "ping" is a very common and effective way to update a device's status. It's essentially a heartbeat mechanism.

The process is simple:

    The server sends a ping to a device.

    The device responds with a pong.

    Upon receiving the pong, the server knows the device is active and can update its last_seen timestamp and set its status to ONLINE.

This approach is highly scalable and is a fundamental part of real-time communication protocols.

What Google Uses

Google’s presence/awareness system (used in Google Chat, Docs, Meet) is not public in detail, but from published papers and reverse-engineered clients:

### Heartbeat + Timeout model

Clients periodically send a heartbeat (ping) to servers (every few seconds).
If the server does not receive a heartbeat within a grace window (say 30s), the device is marked offline.
Last active timestamp
Every event (message send, typing, cursor move) updates last_active.
When no heartbeat is received, user falls back to offline with last_active timestamp.
Multi-device merge algorithm
If any device is active → user is online.
Otherwise → offline, but last_seen = most recent device activity.

```
defmodule MotherServer do
  use GenServer
  require Logger

  @check_interval 30_000       # periodic check interval
  @offline_threshold 60        # seconds without pong to mark offline
  @online "online"
  @offline "offline"

  # Start Mother GenServer for a user
  def start_link(eid) do
    GenServer.start_link(__MODULE__, eid, name: via_tuple(eid))
  end

  defp via_tuple(eid), do: {:via, Registry, {:mother_registry, eid}}

  @impl true
  def init(eid) do
    # ETS table to store last broadcasted status
    state_table = :"state_#{eid}"
    :ets.new(state_table, [:set, :private])
    :ets.insert(state_table, {:last_status, nil})

    schedule_check()
    {:ok, %{eid: eid, state_table: state_table}}
  end

  # Called when a child device sends pong
  def device_pong(eid, device_id) do
    GenServer.cast(via_tuple(eid), {:device_pong, device_id})
  end

  @impl true
  def handle_cast({:device_pong, device_id}, state) do
    # Update last_seen immediately in PgDeviceCache
    Storage.PgDeviceCache.update_last_seen(state.eid, device_id, DateTime.utc_now())
    maybe_broadcast(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:check_devices, state) do
    # Mark devices offline if last_seen too old
    devices = Storage.PgDeviceCache.all_by_owner(state.eid)
    now = DateTime.utc_now()

    updated_devices =
      Enum.map(devices, fn d ->
        diff = DateTime.diff(now, d.last_seen || ~U[1970-01-01 00:00:00Z], :second)

        if diff > @offline_threshold and d.status == @online do
          Storage.PgDeviceCache.mark_offline(d.eid, d.device_id)
          %{d | status: @offline}
        else
          d
        end
      end)

    maybe_broadcast(state, updated_devices)
    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_devices, @check_interval)
  end

  # Broadcast only if overall awareness status changes
  defp maybe_broadcast(state, devices \\ nil) do
    eid = state.eid
    state_table = state.state_table

    devices = devices || Storage.PgDeviceCache.all_by_owner(eid)

    current_status =
      if Enum.any?(devices, &(&1.status == @online)), do: :online, else: :offline

    last_status =
      case :ets.lookup(state_table, :last_status) do
        [{:last_status, s}] -> s
        _ -> nil
      end

    if last_status != current_status do
      :ets.insert(state_table, {:last_status, current_status})
      broadcast_awareness(eid, devices, current_status)
    end
  end

  defp broadcast_awareness(eid, devices, status) do
    friends = Enum.map(devices, & &1.device_id)

    awareness = %Strucs.Awareness{
      owner_eid: eid,
      device_id: "00000000",
      friends: friends,
      status: status,
      last_seen: DateTime.utc_now() |> DateTime.to_unix()
    }

    Logger.info("[Awareness] Broadcasting for #{eid}: #{status}")
    MonitorAppPresence.subscriptions(awareness)
    MonitorAppPresence.broadcast_awareness(eid)
  end
end

```

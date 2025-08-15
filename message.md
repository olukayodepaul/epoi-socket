How offline device B gets updates

Device B is offline when A sends a message

Mother GenServer stores the message in ETS with a version.

Device B cannot receive it immediately because it’s offline.

No need to check online status at send time. Just store the message centrally.

When device B comes online

Device B either:

Pings / syncs with the mother GenServer (pull_new_messages)

Or performs an explicit action to fetch updates.

Mother GenServer responds

Checks DeviceInfo.last_received_version for B

Pulls all messages from ETS with version > last_received_version

Sends them to B

Updates last_received_version after B acknowledges

Two ways to trigger update to offline devices

Pull from the device (recommended)

Device B calls: MotherGenServer.pull_new_messages(user_id, device_id)

Can happen: on login, on reconnect, or periodically (heartbeat).

Push from mother GenServer (optional)

Only works for online devices with a live PID.

If B is offline, push fails → B will still pull later.

✅ Best practice

Mother GenServer does not push to offline devices.

Offline devices are responsible for pulling updates based on their last_received_version.

This keeps things simple, avoids unnecessary checks, and works perfectly with multiple offline devices.

````
Perfect! Let’s do a **simple Elixir example** showing:

1. Device A sends a message → stored in ETS with version assigned by Mother GenServer.
2. Device B pulls its missed messages using `last_received_version`.

We’ll use **two ETS tables**: `:user_devices` and `:messages`.

---

## **1. Setup ETS tables**

```elixir
# Create ETS tables
:ets.new(:user_devices, [:named_table, :set, :public])
:ets.new(:messages, [:named_table, :set, :public])
````

---

## **2. DeviceInfo Struct**

```elixir
defmodule DeviceInfo do
  defstruct [
    :device_id,
    :last_seen,
    :last_received_version  # track last version this device got
  ]
end
```

---

## **3. Message Struct**

```elixir
defmodule Message do
  defstruct [
    :message_id,
    :sender_device_id,
    :receiver_device_id,  # :all or specific device
    :content,
    :timestamp,
    :version
  ]
end
```

---

## **4. Mother GenServer (simplified)**

```elixir
defmodule MotherServer do
  use GenServer

  # Start GenServer
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, Map.put(state, :message_version_counter, 0)}
  end

  # Send message from a device
  def send_message(sender_device_id, receiver_device_id, content) do
    GenServer.call(__MODULE__, {:send_message, sender_device_id, receiver_device_id, content})
  end

  # Pull messages for a device
  def pull_messages(user_id, device_id) do
    GenServer.call(__MODULE__, {:pull_messages, user_id, device_id})
  end

  # Callbacks
  def handle_call({:send_message, sender, receiver, content}, _from, state) do
    version = state.message_version_counter + 1

    message = %Message{
      message_id: "msg_#{version}",
      sender_device_id: sender,
      receiver_device_id: receiver,
      content: content,
      timestamp: :os.system_time(:millisecond),
      version: version
    }

    # Insert message into ETS
    :ets.insert(:messages, {message.message_id, message})

    # Update counter
    {:reply, message, %{state | message_version_counter: version}}
  end

  def handle_call({:pull_messages, user_id, device_id}, _from, state) do
    # Fetch device info
    [{^user_id, ^device_id, device_info}] = :ets.lookup(:user_devices, {user_id, device_id})
    last_version = device_info.last_received_version || 0

    # Get all new messages from ETS
    new_messages =
      :ets.tab2list(:messages)
      |> Enum.map(fn {_id, msg} -> msg end)
      |> Enum.filter(fn msg ->
        msg.version > last_version and (msg.receiver_device_id == device_id or msg.receiver_device_id == :all)
      end)

    # Update last_received_version
    new_last_version =
      case new_messages do
        [] -> last_version
        msgs -> Enum.max(Enum.map(msgs, & &1.version))
      end

    updated_device_info = %{device_info | last_received_version: new_last_version}
    :ets.insert(:user_devices, {user_id, device_id, updated_device_info})

    {:reply, new_messages, state}
  end
end
```

---

## **5. Example Usage**

```elixir
# Insert two devices for user "user_1"
:ets.insert(:user_devices, {"user_1", "device_A", %DeviceInfo{device_id: "device_A", last_seen: :os.system_time(:millisecond), last_received_version: 0}})
:ets.insert(:user_devices, {"user_1", "device_B", %DeviceInfo{device_id: "device_B", last_seen: :os.system_time(:millisecond), last_received_version: 0}})

# Device A sends a message
MotherServer.send_message("device_A", :all, "Hello Device B!")

# Device B pulls missed messages
new_msgs = MotherServer.pull_messages("user_1", "device_B")
IO.inspect(new_msgs)
```

---

### ✅ **What happens**

1. Device A sends a message → stored in ETS with `version = 1`.
2. Device B calls `pull_messages` → receives messages with version > its `last_received_version`.
3. `last_received_version` for Device B is updated to 1.
4. Offline or online, all devices pull messages independently using the **version mechanism**.

---

This example keeps it **simple, central, and offline-friendly**.

We can **next add automatic pulling or periodic sync** if you want to simulate a real-time experience.

Do you want me to show that?

```

```

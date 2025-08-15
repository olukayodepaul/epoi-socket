defmodule Application.Monitor do
  use GenServer
  require Logger

  alias Util.RegistryHelper
  alias DartMessagingServer.MonitorDynamicSupervisor

  # Use GenServer.start/3 instead of start_link/3 to detach from the caller
  def start_link(user_id) do
    GenServer.start(__MODULE__, user_id, name: RegistryHelper.via_monitor_registry(user_id))
  end

  def init(user_id) do
    Logger.info("MotherServer init for user_id=#{user_id}")
    {:ok, %{user_id: user_id, devices: %{}}}
  end

  def handle_cast({:stop_monitor, %{eid: _eid}}, state) do
    {:stop, :normal, state}
  end

  # def handle_cast({:start_mother, user_id}, state) do
  #   MonitorDynamicSupervisor.start_mother(user_id)
  #   {:noreply, state}
  # end
end


# # Insert or update device:
# :ets.insert(:user_devices, {user_id, device_id, %DeviceInfo{
#   device_id: device_id,
#   last_seen: :os.system_time(:millisecond),
#   status: 
#   pending_messages: []
# }})

# Fetch all devices for a user:
# :ets.match_object(:user_devices, {user_id, :"$1", :"$2"})

# Add a pending message for a device:
# [{^user_id, ^device_id, device_info}] = :ets.lookup(:user_devices, {user_id, device_id})
# updated = %{device_info | pending_messages: device_info.pending_messages ++ [message]}
# :ets.insert(:user_devices, {user_id, device_id, updated})




#Message Insert a Message Struct
# message = %Message{
#   message_id: "msg_123",
#   sender_device_id: "device_1",
#   receiver_device_id: :all,  # or specific device id
#   content: "Hello!",
#   timestamp: :os.system_time(:millisecond),
#   version: 1
# }

# :ets.insert(:messages, {message.message_id, message})


# 3. Lookup Messages
# Fetch message by ID:
# [{_id, msg}] = :ets.lookup(:messages, "msg_123")

# Fetch all messages after a certain version:
# :ets.tab2list(:messages)
# |> Enum.map(fn {_id, msg} -> msg end)
# |> Enum.filter(fn msg -> msg.version > last_received_version end)

# ```
# Keep it simple: use an incremental number for the message version.
# Why:
# Easy to compare (version > last_received_version)
# Maintains message order across devices
# Avoids relying on timestamps which can differ between devices
# ```


# def pull_new_messages(user_id, device_id) do
#   # Get device info
#   [{^user_id, ^device_id, device_info}] = :ets.lookup(:user_devices, {user_id, device_id})
#   last_version = device_info.last_received_version || 0

#   # Get all new messages from ETS
#   new_messages =
#     :ets.tab2list(:messages)
#     |> Enum.map(fn {_id, msg} -> msg end)
#     |> Enum.filter(fn msg -> msg.version > last_version end)

#   {new_messages, last_version}
# end



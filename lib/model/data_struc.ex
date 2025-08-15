# defmodule Data.DeviceInfo do
#   @moduledoc """
#   Tracks a single device of a user (simplified)
#   """
#   defstruct [
#     :device_id,               # Unique device identifier
#     :last_seen,               # Last timestamp the device was active
#     :status,                  # Device/user status (:online, :offline, :busy, etc.)
#     :last_received_version,   # Last version of messages/status updates received
#     :ip_address,              # Last known IP address of the device
#     :app_version,             # Version of the app installed on this device
#     :os,                      # Operating system of the device (iOS, Android, etc.)
#     :last_activity,           # Timestamp of last user action
#     :supports_notifications,  # Boolean: can device receive push notifications
#     :supports_media           # Boolean: can device send/receive media files
#   ]

# end


# defmodule Message do
#   @moduledoc """
#   Represents a single message sent between devices
#   """
#   defstruct [
#     :message_id,       # unique identifier for the message
#     :sender_device_id, # device that sent the message
#     :receiver_device_id, # device that should receive the message (or :all for broadcast)
#     :content,          # actual message content
#     :timestamp,        # when message was created
#     :version           # sequential version assigned by mother GenServer
#   ]
# end



# defmodule Data.DeviceInfo do
#   @moduledoc """
#   Tracks a single device of a user in a multi-device system.

#   Fields:
#     - device_id: Unique identifier for the device
#     - last_seen: Timestamp of the last time the device was active
#     - status: Device/user status (:online, :offline, :busy, etc.)
#     - last_received_version: Last version of messages/status updates received
#     - ip_address: Last known IP address of the device
#     - app_version: Version of the app installed on this device
#     - os: Operating system of the device (iOS, Android, etc.)
#     - last_activity: Timestamp of last user action
#     - supports_notifications: Boolean, can device receive push notifications
#     - supports_media: Boolean, can device send/receive media files
#   """
#   defstruct [
#     :device_id,
#     :last_seen,
#     :status,
#     :last_received_version,
#     :ip_address,
#     :app_version,
#     :os,
#     :last_activity,
#     :supports_notifications,
#     :supports_media
#   ]

#   # -----------------------
#   # Example helper functions
#   # -----------------------

#   # Update device status
#   def update_status(device_info, new_status) do
#     %{device_info | status: new_status, last_seen: :os.system_time(:millisecond)}
#   end

#   # Record last activity timestamp
#   def record_activity(device_info) do
#     %{device_info | last_activity: :os.system_time(:millisecond), last_seen: :os.system_time(:millisecond)}
#   end

#   # Update last received version after syncing messages
#   def update_last_received_version(device_info, version) do
#     %{device_info | last_received_version: version}
#   end

#   # Example: mark device as offline
#   def mark_offline(device_info) do
#     %{device_info | status: :offline, last_seen: :os.system_time(:millisecond)}
#   end
# end


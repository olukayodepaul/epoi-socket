defmodule Util.RegistryHelper do
  @moduledoc """
  Helper functions for getting via tuples for device and user GenServers.
  """

  # Returns the via tuple for GenServer name registration for a device
  def via_registry(device_id), do: {:via, Horde.Registry, {DeviceIdRegistry, device_id}}

  # Returns the via tuple for GenServer name registration for a user
  def via_monitor_registry(user_id), do: {:via, Horde.Registry, {UserRegistry, user_id}}
end
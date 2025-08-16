defmodule Util.RegistryHelper do
  @moduledoc """
  Provides via tuples for device and user GenServers.
  """

  # For child sessions
  def via_registry(device_id), do: {:via, Horde.Registry, {DeviceIdRegistry, device_id}}

  # For Mother process
  def via_monitor_registry(user_id), do: {:via, Horde.Registry, {UserRegistry, user_id}}
end

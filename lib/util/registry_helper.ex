defmodule Util.RegistryHelper do
  @moduledoc """
  Helper functions for registering and looking up processes in registries.
  """

  # Returns the via tuple for GenServer name registration for device_id
  def via_registry(device_id), do: {:via, Registry, {DeviceIdRegistry, device_id}}

  # Register process in both registries: EIdRegistry by eid, DeviceIdRegistry by device_id
  def register(eid, device_id) do
    Registry.register(DeviceIdRegistry, device_id, nil)
    Registry.register(EIdRegistry, eid, device_id)
  end
end

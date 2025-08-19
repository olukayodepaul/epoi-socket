defmodule App.Device.Cache do
  @moduledoc """
  ETS-based cache for devices. Also syncs to the configured DB via App.Delegator.
  """

  alias App.PG.Devices
  alias App.Storage.Delegator

  @device_table :device_cache

  # Create ETS table on app start
  def init do
    if :ets.whereis(@device_table) == :undefined do
      :ets.new(@device_table, [:set, :public, :named_table, read_concurrency: true])
    end

    :ok
  end

  # Insert a device into ETS and persist asynchronously
  def save(%Devices{} = device) do
    key = ets_key(device)
    :ets.insert(@device_table, {key, device})
    Task.start(fn -> Delegator.save_device(device) end)
    :ok
  end

  # Fetch device from ETS, fallback to DB if missing
  def fetch(device_id) do
    # Scan ETS for the device
    case :ets.tab2list(@device_table)
        |> Enum.find(fn {_key, device} -> device.device_id == device_id end) do
      nil ->
        # Not found in ETS, fallback to DB
        case Delegator.get_device(device_id) do
          nil ->
            {:error}

          device ->
            # Insert into ETS using standard key
            key = "#{device.eid}:#{device.device_id}"
            :ets.insert(@device_table, {key, device})
            {:ok}
        end

      {key, device} ->
        {:ok}
    end
  end


  # Fetch by device_id only
  def fetch(device_id) do
    case :ets.match_object(@device_table, {:"$1", %{device_id: device_id}}) do
      [{key, device}] -> {:ok, device}
      [] ->
        case Delegator.get_device(device_id) do
          nil -> {:error, :not_found}
          device ->
            key = ets_key(device)
            :ets.insert(@device_table, {key, device})
            {:ok, device}
        end
    end
  end

  # Get device from ETS only
  def get(eid, device_id) do
    key = ets_key(eid, device_id)
    case :ets.lookup(@device_table, key) do
      [{^key, device}] -> device
      [] -> nil
    end
  end

  # Delete device
  def delete(eid, device_id) do
    key = ets_key(eid, device_id)
    :ets.delete(@device_table, key)
    Delegator.delete_device(device_id)
  end

  # Delete only from ETS
  def delete_only_ets(eid, device_id) do
    key = ets_key(eid, device_id)
    :ets.delete(@device_table, key)
  end

  # List all devices in ETS
  def all do
    :ets.tab2list(@device_table)
    |> Enum.map(fn {_key, device} -> device end)
  end

  # List devices by owner (eid)
  def all_by_owner(eid) do
    all()
    |> Enum.filter(&(&1.eid == eid))
  end

  # Update device status
  def update_status(eid, device_id, status) do
    update_device_field(eid, device_id, :status, status)
  end

  # Generic update for any field
  defp update_device_field(eid, device_id, field, value) do
    key = ets_key(eid, device_id)

    case :ets.lookup(@device_table, key) do
      [{^key, device}] ->
        updated = Map.put(device, field, value)
        Delegator.save_device(updated)
        :ets.insert(@device_table, {key, updated})
        {:ok, updated}

      [] ->
        {:error, :not_found}
    end
  end

  # Bulk fetch devices for an owner and cache in ETS
  def fetch_and_cache_by_owner(eid) do
    devices = Delegator.get_all_devices_by_owner(eid)

    Enum.each(devices, fn device ->
      key = ets_key(device)
      :ets.insert(@device_table, {key, device})
    end)

    {:ok, devices}
  end

  # Helper to build ETS key
  defp ets_key(%Devices{eid: eid, device_id: device_id}), do: "#{eid}:#{device_id}"
  defp ets_key(eid, device_id), do: "#{eid}:#{device_id}"
end

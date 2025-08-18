defmodule App.Devices.Cache do
  @moduledoc """
  ETS-based cache for devices. Also syncs to the configured DB via App.Storage.
  """

  alias App.Devices.Device
  alias App.Storage

  @table :devices

  # Create ETS table on app start
  def init do
    unless :ets.whereis(@table) != :undefined do
      :ets.new(@table, [:set, :public, :named_table])
    end
    :ok
  end

  # Insert a device into ETS and persist asynchronously
  def save(%Device{} = device) do
    :ets.insert(@table, {device.device_id, device})
    Task.start(fn -> Storage.save(device) end)
    :ok
  end

  def get(device_id) do
    case :ets.lookup(@table, device_id) do
      [{^device_id, data}] -> data
      [] -> nil
    end
  end

  def update_last_seen(device_id) do
    case :ets.lookup(@table, device_id) do
      [{^device_id, device}] ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        updated_device = %Device{
          device | last_seen: now
        }

        # Save to storage (database or file)
        Storage.save(updated_device)

        # Update in ETS
        :ets.insert(@table, {device.device_id, updated_device})

        {:ok}
        
      [] ->
        {:error}
    end
  end

  def update_last_received_version(device_id, last_received_version) do
    case :ets.lookup(@table, device_id) do
      [{^device_id, device}] ->
        updated_device = %Device{
          device | last_received_version: last_received_version
        }

        # Save to storage
        Storage.save(updated_device)

        # Update in ETS
        :ets.insert(@table, {device.device_id, updated_device})

        {:ok}

      [] ->
        {:error}
    end
  end

  def update_status(device_id, status) do
    case :ets.lookup(@table, device_id) do
      [{^device_id, device}] ->
        updated_device = %Device{
          device | status: status
        }

        # Save to storage
        Storage.save(updated_device)

        # Update in ETS
        :ets.insert(@table, {device.device_id, updated_device})

        {:ok}

      [] ->
        {:error}
    end
  end
  
  def fetch(device_id) do
    case Storage.get(device_id) do
      nil ->
        {:error}
      device ->
        # Update fields since device is back online
        updated_device = %Device{
          device  | status: "online", last_seen: DateTime.utc_now() |> DateTime.truncate(:second)
        }
        # Save back to DB (acts as update)
        Storage.save(updated_device)
        # Cache in ETS
        :ets.insert(@table, {device.device_id, updated_device})
        {:ok}
    end
  end

  def delete(device_id) do
    :ets.delete(@table, device_id)
    Storage.delete(device_id)
  end

  def delete_only_ets(device_id) do
    :ets.delete(@table, device_id)
  end

  def all do
    :ets.tab2list(@table) |> Enum.map(fn {_key, device} -> device end)
  end

  # List devices by user from ETS
  def all_by_user(eid) do
    :ets.tab2list(@table)
    |> Enum.map(fn {_key, device} -> device end)
    |> Enum.filter(fn device -> device.eid == eid end)
  end

end

#App.Devices.Cache.all_by_user("paul@domain.com")
#App.Devices.Cache.get("aaaaa")
#App.Devices.Cache.update_last_received_version("aaaaa", 50)
#App.Devices.Cache.update_status("aaaaa", "offline")
#App.Devices.Cache.update_last_seen("aaaaa")
 

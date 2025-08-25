defmodule Storage.PgDeviceCache do
  @moduledoc """
  ETS-based cache for devices. Also syncs to the configured DB via App.Delegator.
  """


  alias Storage.{DbDelegator,PgDevicesSchema}

  @device_table :device_cache
  @online "online"

  # Create ETS table on app start
  def init do
    if :ets.whereis(@device_table) == :undefined do
      :ets.new(@device_table, [:set, :public, :named_table, read_concurrency: true])
    end
    :ok
  end

  # Insert a device into ETS and persist asynchronously
  def save(%PgDevicesSchema{} = device) do
    key = ets_key(device)
    :ets.insert(@device_table, {key, device})
    Task.start(fn -> DbDelegator.save_device(device) end)
    :ok
  end

  # Fetch device from ETS, fallback to DB if missing, always update with current info
  def fetch(device_id, sw_pid) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    pid_str = sw_pid |> :erlang.pid_to_list() |> to_string()

    case :ets.tab2list(@device_table)
        |> Enum.find(fn {_key, device} -> device.device_id == device_id end) do
      nil ->
        # Not found in ETS → fallback to DB
        case DbDelegator.get_device(device_id) do
          nil ->
            {:error}

          device ->
            key = "#{device.eid}:#{device.device_id}"

            updated_device = %PgDevicesSchema{
              device
              | ws_pid: pid_str,
                last_seen: now,
                status: "online"
            }

            DbDelegator.save_device(updated_device)
            :ets.insert(@device_table, {key, updated_device})

            {:ok}
        end

      {key, device} ->
        # Found in ETS → just update info
        updated_device = %PgDevicesSchema{
          device
          | ws_pid: pid_str,
            last_seen: now,
            status: "online"
        }

        DbDelegator.save_device(updated_device)
        :ets.insert(@device_table, {key, updated_device})

        {:ok}
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

  def delete(eid, device_id) do
    key = ets_key(eid, device_id)
    case :ets.whereis(@device_table) do
      :undefined ->
        :ok
      _tid ->
        :ets.delete(@device_table, key)
        _ = DbDelegator.delete_device(device_id)
        :ok
    end
  end

  def delete_only_ets(eid, device_id) do
    case :ets.whereis(@device_table) do
    :undefined -> :ok  
    _tid -> 
      key = ets_key(eid, device_id)
      :ets.delete(@device_table, key)
    end
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

  #This is use to drive awareless of the users.
  def awareness(eid) do
    devices = all_by_owner(eid)

    cond do
      devices == [] ->
        {:offline, nil}

      Enum.any?(devices, &(&1.status == @online)) ->
        :online

      true ->
        last_seen =
          devices
          |> Enum.map(& &1.last_seen)
          |> Enum.reject(&is_nil/1)
          |> Enum.max_by(& &1, fn -> nil end)

        {:offline, last_seen}
    end
  end

  # Update device status and last_seen//pong can also use this function
  def update_status(eid, device_id, status \\ @online) do
    key = ets_key(eid, device_id)

    case :ets.lookup(@device_table, key) do
      [{^key, device}] ->
        updated_device = %PgDevicesSchema{
          device
          | status: status,
            last_seen: DateTime.utc_now() |> DateTime.truncate(:second)
        }

        :ets.insert(@device_table, {key, updated_device})
        Task.start(fn -> DbDelegator.save_device(updated_device) end)
        {:ok, updated_device}

      [] ->
        {:error, :not_found}
    end
  end

  def update_version(eid, device_id, last_received_version, status \\ @online) do
    key = ets_key(eid, device_id)

    case :ets.lookup(@device_table, key) do
      [{^key, device}] ->
        updated_device = %PgDevicesSchema{
          device
          | status: status,
            last_seen: DateTime.utc_now() |> DateTime.truncate(:second),
            last_received_version: last_received_version
        }

        :ets.insert(@device_table, {key, updated_device})
        Task.start(fn -> DbDelegator.save_device(updated_device) end)
        {:ok, updated_device}

      [] ->
        {:error, :not_found}
    end
  end

  # Helper to build ETS key
  defp ets_key(%PgDevicesSchema{eid: eid, device_id: device_id}), do: "#{eid}:#{device_id}"
  defp ets_key(eid, device_id), do: "#{eid}:#{device_id}"
  
  
end



# App.Device.Cache.get("a@domain.com","aaaaa1")
# App.Device.Cache.update_version("a@domain.com", "aaaaa1", 30)
#device=ccccc2 owner=c@domain.com subscribed to 2 friends
#device= owner= subscribed to 0 friends
# App.Device.Cache.awareness("a@domain.com")
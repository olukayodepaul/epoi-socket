defmodule Storage.PgDeviceCache do
  @moduledoc """
  ETS-based cache for devices. Also syncs to the configured DB via App.Delegator.
  """


  alias Storage.{DbDelegator,PgDevicesSchema}


  @online "ONLINE"

  defp table_name(eid), do: String.to_atom("device_#{eid}")
  # Create ETS table on app start
  def init(eid) do
    table = table_name(eid)
    if :ets.whereis(table) == :undefined do
      :ets.new(table, [:set, :public, :named_table, read_concurrency: true])
    end
    :ok
  end

  # Insert a device into ETS and persist asynchronously
  def save(%PgDevicesSchema{} = device, eid) do
    key = ets_key(device)
    table = table_name(eid)
    :ets.insert(table, {key, device})
    Task.start(fn -> DbDelegator.save_device(device) end)
    :ok
  end

  # Fetch device from ETS, fallback to DB if missing, always update with current info
  def fetch(device_id, eid, sw_pid) do
    table = table_name(eid)
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    pid_str = sw_pid |> :erlang.pid_to_list() |> to_string()

    case :ets.tab2list(table)
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
                status: "ONLINE",
                status_source: "LOGIN"

            }

            DbDelegator.save_device(updated_device)
            :ets.insert(table, {key, updated_device})

            {:ok}
        end

      {key, device} ->
        # Found in ETS → just update info
        updated_device = %PgDevicesSchema{
          device
          | ws_pid: pid_str,
            last_seen: now,
            status: "ONLINE",
            status_source: "LOGIN"
        }

        DbDelegator.save_device(updated_device)
        :ets.insert(table, {key, updated_device})

        {:ok}
    end
  end

  # Get device from ETS only
  def get(eid, device_id) do
    table = table_name(eid)
    key = ets_key(eid, device_id)
    case :ets.lookup(table, key) do
      [{^key, device}] -> device
      [] -> nil
    end
  end

  def delete(eid, device_id) do
    table = table_name(eid)
    key = ets_key(eid, device_id)
    case :ets.whereis(table) do
      :undefined ->
        :ok
      _tid ->
        :ets.delete(table, key)
        _ = DbDelegator.delete_device(device_id)
        :ok
    end
  end

  def delete_only_ets(device_id, eid) do
    table = table_name(eid)
    case :ets.whereis(table) do
    :undefined -> :ok  
    _tid -> 
      key = ets_key(eid, device_id)
      :ets.delete(table, key)
    end
  end

  # List all devices in ETS
  def all(eid) do
    table = table_name(eid)
    :ets.tab2list(table)
    |> Enum.map(fn {_key, device} -> device end)
  end

  # List devices by owner (eid)
  def all_by_owner(eid) do
    all(eid)
    |> Enum.filter(&(&1.eid == eid))
  end

  # Update device status and last_seen//pong can also use this function
  def update_status(eid, device_id, status_source, status  \\ @online) do
  
    table = table_name(eid)
    key = ets_key(eid, device_id)

    case :ets.lookup(table, key) do
      [{^key, device}] ->
        updated_device = %PgDevicesSchema{
          device
          | status: status,
            status_source: status_source,
            last_seen: DateTime.utc_now() |> DateTime.truncate(:second)
        }

        :ets.insert(table, {key, updated_device})
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





# Storage.PgDeviceCache.all("a@domain.com")
# Storage.PgDeviceCache.all("b@domain.com")
# Storage.PgDeviceCache.all_by_owner("a@domain.com")
# Storage.PgDeviceCache.update_version("a@domain.com", "aaaaa1", 35, "offline")
# Storage.PgDeviceCache.awareness("a@domain.com")
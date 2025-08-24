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

  # Fetch device from ETS, fallback to DB if missing, always update with current info
  def fetch(device_id, sw_pid) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    pid_str = sw_pid |> :erlang.pid_to_list() |> to_string()

    case :ets.tab2list(@device_table)
        |> Enum.find(fn {_key, device} -> device.device_id == device_id end) do
      nil ->
        # Not found in ETS → fallback to DB
        case Delegator.get_device(device_id) do
          nil ->
            {:error}

          device ->
            key = "#{device.eid}:#{device.device_id}"

            updated_device = %Devices{
              device
              | ws_pid: pid_str,
                last_seen: now,
                status: "online"
            }

            Delegator.save_device(updated_device)
            :ets.insert(@device_table, {key, updated_device})

            {:ok}
        end

      {key, device} ->
        # Found in ETS → just update info
        updated_device = %Devices{
          device
          | ws_pid: pid_str,
            last_seen: now,
            status: "online"
        }

        Delegator.save_device(updated_device)
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
    case :ets.whereis(@device_table) do
    :undefined -> :ok  
    tid -> 
      key = ets_key(eid, device_id)
      :ets.delete(@device_table, key)
      Delegator.delete_device(device_id)
    end
  end

  def delete_only_ets(eid, device_id) do
    case :ets.whereis(@device_table) do
    :undefined -> :ok  
    tid -> 
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


  # Helper to build ETS key
  defp ets_key(%Devices{eid: eid, device_id: device_id}), do: "#{eid}:#{device_id}"
  defp ets_key(eid, device_id), do: "#{eid}:#{device_id}"
end




# App.Device.Cache.get("d@domain.com","ddddd1")
# App.Device.Cache.get("c@domain.com","ccccc2")

#device=ccccc2 owner=c@domain.com subscribed to 2 friends
#device= owner= subscribed to 0 friends
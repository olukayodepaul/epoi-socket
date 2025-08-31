defmodule Storage.GlobalSubscriberCache do

  alias Storage.DbDelegator

  # Build ETS table name per owner
  def table_name(eid), do: String.to_atom("global_subscriber_#{eid}")

  @doc """
  Initialize ETS table for an owner.
  """
  def init(eid) do
    table = table_name(eid)

    if :ets.whereis(table) == :undefined do
      :ets.new(table, [:set, :public, :named_table, read_concurrency: true])
    end

    :ok
  end

  @doc """
  Fetch subscriber list for owner_eid and cache in ETS.
  Only subscribers with `awareness_status == "allow"`.
  """
  def fetch_subscriber_by_owners_eid(owner_eid) do
    table = table_name(owner_eid)
    key = "subscriber_list#{owner_eid}"

    case :ets.lookup(table, key) do
      [{^key, subscribers}] ->
        {:ok, subscribers}

      [] ->
        case DbDelegator.all_subscribers_by_user(owner_eid) do
          nil ->
            {:error, :not_found}

          subscribers when is_list(subscribers) ->
            allowed_subscribers =
              Enum.filter(subscribers, fn s -> Map.get(s, :awareness_status) == "allow" end)

            :ets.insert(table, {key, allowed_subscribers})
            {:ok, allowed_subscribers}
        end
    end
  end

  # ------------------------------
  # Subscribers Information
  # ------------------------------

  defp device_key(owner_id, subscriber_id, device_id),
    do: "device_#{owner_id}_#{subscriber_id}_#{device_id}"

  @doc """
  Insert or update a device awareness record for a subscriber.
  """
  def put_subscriber_device(owner_id, subscriber_id, device_id, status, latitude, longitude, last_seen \\ DateTime.utc_now()) do
    table = table_name(owner_id)

    record = %{
      owner_id: owner_id,
      subscriber_id: subscriber_id,
      device_id: device_id,
      status: status,
      latitude: latitude,
      longitude: longitude,
      last_seen: last_seen
    }

    :ets.insert(table, {device_key(owner_id, subscriber_id, device_id), record})
    {:ok, record}
  end

  @doc """
  Update an existing device record. If not exists, insert it.
  """
  def update_subscriber_device(owner_id, subscriber_id, device_id, status, latitude, longitude, last_seen \\ DateTime.utc_now()) do
    put_subscriber_device(owner_id, subscriber_id, device_id, status, latitude, longitude, last_seen)
  end

  @doc """
  Fetch a single device record.
  """
  def get_subscriber_device(owner_id, subscriber_id, device_id) do
    table = table_name(owner_id)

    case :ets.lookup(table, device_key(owner_id, subscriber_id, device_id)) do
      [{_, record}] -> {:ok, record}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Fetch all devices for a subscriber.
  Returns a list of device maps.
  """
  def fetch_subscriber_devices(owner_id, subscriber_id) do
    table = table_name(owner_id)

    # Match all keys starting with device_#{owner_id}_#{subscriber_id}_
    match_pattern = {:"$1", :"$2"}
    results =
      :ets.tab2list(table)
      |> Enum.filter(fn {k, _v} ->
        String.starts_with?(k, "device_#{owner_id}_#{subscriber_id}_")
      end)
      |> Enum.map(fn {_k, v} -> v end)

    {:ok, results}
  end

  @doc """
  Delete a device record.
  """
  def delete_subscriber_device(owner_id, subscriber_id, device_id) do
    table = table_name(owner_id)
    :ets.delete(table, device_key(owner_id, subscriber_id, device_id))
    :ok
  end
end

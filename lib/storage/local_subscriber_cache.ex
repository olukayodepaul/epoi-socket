defmodule Storage.LocalSubscriberCache do
  @moduledoc """
  ETS-based cache for per-owner per-device presence and subscriber list.
  Each device gets its own ETS table to avoid conflicts.
  """

  # Generate ETS table name for a device
  def table_name(device_id), do: String.to_atom("local_presence_#{device_id}")

  # Initialize ETS table for this device
  def init(device_id) do
    table = table_name(device_id)
    if :ets.whereis(table) == :undefined do
      :ets.new(table, [:set, :public, :named_table, read_concurrency: true])
    end
    :ok
  end

  # Save full presence struct per device
  def put(%Model.PresenceSubscription{owner: owner, device_id: device_id} = presence) do
    table = table_name(device_id)
    :ets.insert(table, {{:presence, owner}, presence})
    :ok
  end

  # Save list of subscribers for an owner (per device)
  def subscribers(device_id, owner, subscribers) when is_list(subscribers) do
    table = table_name(device_id)
    :ets.insert(table, {{:subscribers, owner}, subscribers})
    :ok
  end

  # Fetch presence of a specific owner on a specific device
  def get_presence(owner, device_id) do
    table = table_name(device_id)
    case :ets.lookup(table, {:presence, owner}) do
      [{{:presence, ^owner}, presence}] -> {:ok, presence}
      [] -> {:error, :not_found}
    end
  end

  # Fetch all presence entries for a device (all owners)
  def get_all_presence(device_id) do
    table = table_name(device_id)

    :ets.tab2list(table)
    |> Enum.filter(fn
      {{:presence, _owner}, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {{:presence, _owner}, presence} -> presence end)
  end

  # Fetch subscribers for an owner on a device
  def get_subscribers(device_id, owner) do
    table = table_name(device_id)
    case :ets.lookup(table, {:subscribers, owner}) do
      [{{:subscribers, ^owner}, subs}] -> {:ok, subs}
      [] -> {:error, :not_found}
    end
  end

  # Apply diffs to a specific device's presence
  def apply_diff(owner, device_id, {:online, _from, status}),
    do: update_presence(owner, device_id, &%{&1 | online: status})

  def apply_diff(owner, device_id, {:typing, _from, status}),
    do: update_presence(owner, device_id, &%{&1 | typing: status})

  def apply_diff(owner, device_id, {:recording, _from, status}),
    do: update_presence(owner, device_id, &%{&1 | recording: status})

  def apply_diff(owner, device_id, {:last_seen, _from, ts}),
    do: update_presence(owner, device_id, &%{&1 | last_seen: ts})

  def delete(device_id) do
    table = table_name(device_id)
    case :ets.whereis(table) do
      :undefined -> :ok
      tid when is_reference(tid) -> :ets.delete(table)
      tid when is_integer(tid) -> :ets.delete(table)
    end
    :ok
  end

  # Internal helper to update presence
  defp update_presence(owner, device_id, fun) do
    case get_presence(owner, device_id) do
      {:ok, presence} ->
        new_presence = fun.(presence)
        put(new_presence)
        {:ok, new_presence}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end
end


#Storage.LocalSubscriberCache.get_subscribers("aaaaa1", "a@domain.com")
#Storage.LocalSubscriberCache.get_subscribers("aaaaa2", "a@domain.com")
# Storage.LocalSubscriberCache.get_all_presence("aaaaa1")
# Storage.LocalSubscriberCache.get_presence("a@domain.com", "aaaaa1")
# Storage.LocalSubscriberCache.get_presence("a@domain.com", "aaaaa2")



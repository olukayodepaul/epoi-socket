defmodule Storage.LocalSubscriberCache do
  @moduledoc """
  ETS-based cache for per-owner per-device awareness/subscriber list.
  Each device gets its own ETS table to avoid conflicts.
  """

  def table_name(device_id), do: String.to_atom("local_presence_#{device_id}")

  def init(device_id) do
    table = table_name(device_id)
    if :ets.whereis(table) == :undefined do
      :ets.new(table, [:set, :public, :named_table, read_concurrency: true])
    end
    :ok
  end

  # Save awareness struct per device
  def put(%Strucs.Awareness{owner_eid: owner_eid, device_id: device_id} = awareness) do
    table = table_name(device_id)
    :ets.insert(table, {{:presence, owner_eid}, awareness})
    :ok
  end

  def subscribers(device_id, owner_eid, subscribers) when is_list(subscribers) do
    table = table_name(device_id)
    :ets.insert(table, {{:subscribers, owner_eid}, subscribers})
    :ok
  end

  def get_all_presence(device_id) do
    table = table_name(device_id)

    :ets.tab2list(table)
    |> Enum.filter(fn
      {{:presence, _owner}, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {{:presence, _owner}, awareness} -> awareness end)
  end

  def get_subscribers(device_id, owner_eid) do
    table = table_name(device_id)
    case :ets.lookup(table, {:subscribers, owner_eid}) do
      [{{:subscribers, ^owner_eid}, subs}] -> {:ok, subs}
      [] -> {:error, :not_found}
    end
  end

  def get_presence(owner_eid, device_id) do
    table = table_name(device_id)
    case :ets.lookup(table, {:presence, owner_eid}) do
      [{{:presence, ^owner_eid}, awareness}] -> {:ok, awareness}
      [] -> {:error, :not_found}
    end
  end

  # check the number of table created locally and delete all
  # when next the child is coming, the child can still pull the details
  def delete(device_id) do
    table = table_name(device_id)
    case :ets.whereis(table) do
      :undefined -> :ok
      _tid -> :ets.delete(table)
    end
    :ok
  end

end



#Storage.LocalSubscriberCache.get_subscribers("aaaaa1", "a@domain.com")
#Storage.LocalSubscriberCache.get_presence("a@domain.com","aaaaa1")


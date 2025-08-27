defmodule App.AllRegistry do

  require Logger

  def sent_subscriber(device_id, eid, subscriber) do
    IO.inspect(3)
    {:ok, subscribers} = subscriber
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] ->
        GenServer.cast(pid, {:processor_get_all_subcriber, {device_id, eid, subscribers}})
        :ok
      [] ->
        {:error}
    end
  end

  def set_startup_status({eid, device_id, ws_pid}) do
    IO.inspect(1)
    case Horde.Registry.lookup(UserRegistry, eid) do
      [{pid, _}] ->
        GenServer.cast(pid, {:monitor_startup_status, %{eid: eid, device_id: device_id, ws_pid: ws_pid }})
        :ok
      []->
        Logger.warning("No registry entry for #{device_id}, cannot maybe_start_mother")
        {:error}
    end
  end

  def terminate_child_process({eid, device_id}) do
    case Horde.Registry.lookup(UserRegistry, eid) do
    [{pid, _}] ->
      GenServer.cast(pid, {:monitor_terminate_child, {eid, device_id}})
      :ok
    [] ->
      Logger.warning("No registry entry for #{device_id}, cannot maybe_start_mother")
      :error
    end
  end

  def handle_awareness(awareness, device_id) do
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] ->
        GenServer.cast(pid, {:processor_awareness, awareness})
        :ok
      [] ->
        Logger.warning("No registry entry for #{device_id}, cannot maybe_start_mother")
        :error
    end
  end

  def send_subscriber_last_seen_to_monitor({owner_eid, eid, device_id, status}) do
    case Horde.Registry.lookup(UserRegistry, eid) do
      [{pid, _}] ->
        GenServer.cast(pid, {:monitor_subscriber_last_seen, %{from: owner_eid, to: eid, device_id: device_id, status: status}})
        :ok
      [] ->
        :error
    end
  end

  def pong_counter_reset(device_id, eid) do
    case Horde.Registry.lookup(UserRegistry, eid) do
      [{pid, _}] ->
        GenServer.cast(pid, {:monotor_pong_counter, {eid, device_id}})
        :ok
      [] ->
        :error
    end
  end

end
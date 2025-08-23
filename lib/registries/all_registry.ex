defmodule App.AllRegistry do

  require Logger

  def sent_subscriber(device_id, eid, subscriber) do
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
      {:error}
    end
  end

  def handle_awareness(awareness, device_id) do
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] ->
        GenServer.cast(pid, {:processor_awareness, awareness})
        :ok
      [] ->
        Logger.warning("No registry entry for #{device_id}, cannot maybe_start_mother")
        {:error}
    end
  end

  # def handle_awareness_response(sw_pid, awareness) do
  #   send(sw_pid, {:socket_awareness_response, awareness})
  # end


end
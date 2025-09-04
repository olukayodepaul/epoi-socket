defmodule App.AllRegistry do

  require Logger
  alias ApplicationServer.Configuration
  
  def setup_client_init({eid, device_id, ws_pid}) do
    case Horde.Registry.lookup(UserRegistry, eid) do
      [{pid, _}] ->
        GenServer.cast(pid, {:m_setup_client_init, %{eid: eid, device_id: device_id, ws_pid: ws_pid }})
        :ok
      []->
        Logger.warning("5 No registry entry for #{device_id}, cannot maybe_start_mother")
        {:error}
    end
  end

  def schedule_ping_registry(device_id, interval) do
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] -> 
        Process.send_after(pid, {:send_ping, interval}, interval)
      [] -> 
        Logger.warning("4 No registry entry for #{device_id}, cannot schedule ping")
    end
  end

  def handle_pong_registry(device_id, sent_time) do
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] ->
        Logger.info("Forwarding pong to Application.Processor for #{device_id}")
        GenServer.cast(pid, {:received_pong, {device_id, sent_time}})
      [] ->
        Logger.warning("3 No Application.Processor GenServer found for pong: #{device_id}")
    end
  end

 

  def send_pong_to_server(device_id, eid, status \\ "ONLINE") do
    # we can check if the registry id global or local.
    case Horde.Registry.lookup(UserRegistry, eid) do
      [{pid, _}] ->
        GenServer.cast(pid, {:send_pong, {eid, device_id, status}})
        :ok
      [] ->
        :error
    end
  end

  def fan_out_to_children(device_id, eid, %Strucs.Awareness{} = awareness) do
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] ->
        GenServer.cast(pid, {:fan_out_to_children, {device_id, eid, awareness}})
        :ok
      [] ->
        Logger.warning("1 No registry entry for #{eid}, cannot maybe_start_mother")
        :error
    end
  end

  def handle_ping_pong_registry(%{device_id: device_id} = state, data) do
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] ->
        GenServer.cast(pid, {:processor_handle_ping_pong, data})
        :ok
      [] ->
        :error
    end
  end

  def send_pong_pong_to_socket_monitor(%{ ws_pid: ws_pid, binary: binary}) do
    send(ws_pid, {:binary, binary})
    :ok
  end

  def handle_handle_logout_registry(%{device_id: device_id} = state, data) do
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] ->
        GenServer.cast(pid, {:processor_handle_logout, data})
        :ok
      [] ->
        :error
    end
  end

  def handle_logout_monitor_and_socket(%{ device_id: device_id, eid: eid, ws_pid: ws_pid, binary: binary}) do
    send(ws_pid, {:custome_binary, binary})
    case Horde.Registry.lookup(UserRegistry, eid) do
      [{pid, _}] ->
        GenServer.cast(pid, {:monitor_handle_logout, %{device_id: device_id, eid: eid}})
        :ok
      [] ->
        :error
    end
  end

  def terminate_child_process({eid, device_id}) do
    IO.inspect("jncjdsn jdncjsdanc jdnacj. djsacihadsbc dsanciadjs ")
    case Horde.Registry.lookup(UserRegistry, eid) do
    [{pid, _}] ->
      GenServer.cast(pid, {:monitor_handle_logout, %{device_id: device_id, eid: eid}})
      :ok
    [] ->
      Logger.warning("2 No registry entry for #{device_id}, cannot maybe_start_mother")
      :error
    end
  end

end
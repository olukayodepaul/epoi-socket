defmodule App.AllRegistry do

  require Logger
  alias ApplicationServer.Configuration
  alias OfflineQueue
  
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

  def handle_logout_terminate(%{ ws_pid: ws_pid, binary: binary}) do
    send(ws_pid, {:custome_binary, binary})
  end

  def terminate_child_process({eid, device_id}) do
    case Horde.Registry.lookup(UserRegistry, eid) do
    [{pid, _}] ->
      GenServer.cast(pid, {:monitor_handle_logout, %{device_id: device_id, eid: eid}})
      :ok
    [] ->
      Logger.warning("2 No registry entry for #{device_id}, cannot maybe_start_mother")
      :error
    end
  end

  def handle_token_revoke_request_registry(%{device_id: device_id} = state, data) do
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
    [{pid, _}] ->
      GenServer.cast(pid, {:processor_handle_token_revoke_request, data})
      :ok
    [] ->
      Logger.warning("2 No registry entry for #{device_id}, cannot maybe_start_mother")
      :error
    end
  end

  # from socket child genserver prossessor : # Process 1
  def handle_subscribe_request_registry(%{device_id: device_id} = state, data) do
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
    [{pid, _}] ->
      GenServer.cast(pid, {:processor_subscribe_request, data})
      :ok
    [] ->
      Logger.warning("2 No registry entry for #{device_id}, cannot maybe_start_mother")
      :error
    end
  end

  # from child genserver prossessor to mother monitor genserver 1 : # Process 3
  def send_subscriber_to_sender(subscription_id, from_eid, to_eid, data) do
    case Horde.Registry.lookup(UserRegistry, from_eid) do
    [{pid, _}] ->
      GenServer.cast(pid, {:monitor_send_subscriber_to_sender, {subscription_id, from_eid, to_eid, data}})
      :ok
    [] ->
      Logger.warning("2 No registry entry for #{to_eid}, cannot maybe_start_mother")
      :error
    end
  end

  # from mother monitor genserver to child genserver prossessor receiver  : # Process 5
  def send_subscriber_to_receiver(subscription_id, from_eid, to_eid, data) do
    IO.inspect({subscription_id, from_eid, to_eid, data})
    case Horde.Registry.lookup(UserRegistry, to_eid) do
    [{pid, _}] ->
      GenServer.cast(pid, {:monitor_send_subscriber_to_receiver, {to_eid, data}})
      :ok
    [] ->
      OfflineQueue.enqueue(subscription_id, from_eid, to_eid , data)
      :error
    end
  end

  # Process 8
  def process_fan_out_relay(device_id, data) do
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] ->
        Logger.debug("Fanning out to device #{device_id}")
        GenServer.cast(pid, {:process_fan_out_relay, data})
      [] ->
        Logger.warning("Device #{device_id} not alive in registry (DB says ONLINE)")
    end
  end

  # Process 9
  def socker_fan_out_relay(ws_pid, data) do
    send(ws_pid, {:binary, data})
  end

  #pr 1
  def handle_subscribe_response_registry(%{device_id: device_id} = state, data) do
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
    [{pid, _}] ->
      GenServer.cast(pid, {:processor_subscribe_response, data})
      :ok
    [] ->
      Logger.warning("2 No registry entry for #{device_id}, cannot maybe_start_mother")
      :error
    end
  end
  
  def send_subscriber_response_to_monitor(status, one_way, subscription_id, from_eid, to_eid, data) do
    case Horde.Registry.lookup(UserRegistry, from_eid) do
    [{pid, _}] ->
      GenServer.cast(pid, {:monitor_send_subscriber_response_to_monitor, {status, one_way, subscription_id, from_eid, to_eid, data}})
      :ok
    [] ->
      Logger.warning("2 No registry entry for #{to_eid}, cannot maybe_start_mother")
      :error
    end
  end

  #pr 3
  def send_subscriber_response_to_receiver(status, one_way, subscription_id, from_eid, to_eid, data) do
    case Horde.Registry.lookup(UserRegistry, to_eid) do
    [{pid, _}] ->
      GenServer.cast(pid, {:send_subscriber_response_to_sender_server, {status, one_way, subscription_id, from_eid, to_eid, data}})
      :ok
    [] ->
      OfflineQueue.enqueue(subscription_id, from_eid, to_eid , data)
      :error
    end
  end


end



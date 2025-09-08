defmodule Application.Processor do
  use GenServer
  require Logger
  alias Util.{RegistryHelper, PingPongHelper, TokenRevoked}
  alias App.AllRegistry
  alias ApplicationServer.Configuration
  alias Local.DeviceStateChange
  alias Security.TokenVerifier

  # Start GenServer for device session
  def start_link({_eid, device_id, _ws_pid} = state) do
    GenServer.start_link(__MODULE__, state, name: RegistryHelper.via_registry(device_id))
  end

  @impl true
  def init({eid, device_id, ws_pid}) do

    AllRegistry.setup_client_init({eid, device_id, ws_pid}) # pass
    PingPongHelper.schedule_ping(device_id)

    {:ok, %{
      missed_pongs: 0, 
      pong_counter: 0, 
      timer: DateTime.utc_now(), 
      eid: eid, 
      device_id: device_id, 
      ws_pid: ws_pid,
      last_rtt: nil, 
      max_missed_pongs_adaptive: Configuration.initial_adaptive_max_missed(), 
      last_send_ping: nil,
      last_state_change: DateTime.utc_now()
    }}
    
  end

  # Handle ping/pong
  @impl true
  def handle_info({:send_ping, interval}, state) do
    PingPongHelper.handle_ping(%{state | last_rtt: interval} )
  end

  def handle_cast({:received_pong, {device_id, receive_time}}, state) do 
    PingPongHelper.pongs_received(device_id, receive_time, state)
  end
  
  def handle_cast({:processor_handle_ping_pong, data}, %{ ws_pid: ws_pid} = state) do
    #send state to parent that users in online
    msg = Bimip.MessageScheme.decode(data)
    case msg.payload do
      {:ping_pong, %Bimip.PingPong{type: 1} = ping_msg} ->
        # Build PONG response
        pong_response = %Bimip.PingPong{
          to: %Bimip.Identity{
            eid: ping_msg.to.eid,
            connection_resource_id: ping_msg.to.connection_resource_id
          },
          type: 2, # PONG
          ping_time: ping_msg.ping_time,
          pong_time: System.system_time(:millisecond),
          ping_id: ping_msg.ping_id
        }

        response_msg = %Bimip.MessageScheme{
          route: 4,
          payload: {:ping_pong, pong_response}
        }

        binary = Bimip.MessageScheme.encode(response_msg)
        AllRegistry.send_pong_pong_to_socket_monitor(%{ ws_pid: ws_pid, binary: binary})
        {:noreply, state}
      _ ->
        # return error
        {:noreply, state}
    end
    
  end

  def handle_cast({:processor_handle_token_revoke_request, data}, %{ ws_pid: ws_pid} = state) do
    msg = Bimip.MessageScheme.decode(data)
    
    case msg.payload do
    {:token_revoke_request,
      %Bimip.TokenRevokeRequest{
        to: %Bimip.Identity{eid: eid, connection_resource_id: conn_res_id},
        token: token,
        timestamp: timestamp,
        reason: reason
      }} ->
        with {:ok, claims} <- Security.TokenVerifier.verify_token(token),
            jti when is_binary(jti) <- Map.get(claims, "jti"),
            exp when is_integer(exp) <- Map.get(claims, "exp") do

          TokenRevoked.store_revocation(jti, exp)

          revoke_response = %Bimip.TokenRevokeResponse{
            to: %Bimip.Identity{
              eid: eid,
              connection_resource_id: conn_res_id
            },
            status: 2,
            timestamp: System.system_time(:millisecond),
            reason: reason
          }

          response_msg = %Bimip.MessageScheme{
            route: 6,
            payload: {:token_revoke_response, revoke_response}
          }
          
          binary = Bimip.MessageScheme.encode(response_msg)
          DeviceStateChange.delete_table(eid, conn_res_id)
          AllRegistry.handle_logout_terminate(%{ws_pid: ws_pid, binary: binary})
          AllRegistry.terminate_child_process({eid, conn_res_id})

          {:noreply, state}
        else
          {:error, reason} ->
            IO.inspect(reason, label: "Token verification failed")
            {:noreply, state}

          _ ->
            IO.inspect("Missing jti in token", label: "Token revoke error")
            {:noreply, state}
        end

      _ ->
        IO.inspect(msg, label: "Unexpected payload in token revoke")
        {:noreply, state}
    end

  end

  def handle_cast( {:processor_handle_logout, data}, %{ device_id: device_id, eid: eid, ws_pid: ws_pid} = state) do

    msg = Bimip.MessageScheme.decode(data)
    case msg.payload do
      {:logout, %Bimip.Logout{type: 1} = logout_msg} ->

        logout_response = %Bimip.Logout{
          to: %Bimip.Identity{
            eid: logout_msg.to.eid,
            connection_resource_id: logout_msg.to.connection_resource_id
          },
          type: 2,          # RESPONSE
          status: 3,        # SUCCESS
          timestamp: System.system_time(:millisecond)
        }

        # Wrap in MessageScheme
        response_msg = %Bimip.MessageScheme{
          route: 11,
          payload: {:logout, logout_response}
        }

        # # Encode and send as reply while stopping socket
        binary = Bimip.MessageScheme.encode(response_msg)
        DeviceStateChange.delete_table(eid, device_id)
        AllRegistry.handle_logout_terminate(%{ws_pid: ws_pid, binary: binary})
        AllRegistry.terminate_child_process({eid, device_id})
        {:stop, :normal, state}
      
      _ ->
        # return error
        {:noreply, state}
    end
  end

  def handle_cast({:fan_out_to_children, {owner_device_id, eid, awareness}},   state) do
    # Build the AwarenessNotification
    notification = %Bimip.AwarenessNotification{
      from: %Bimip.Identity{eid: awareness.owner_eid},
      to: %Bimip.Identity{eid: eid},
      last_seen: DateTime.to_unix(awareness.last_seen, :second),
      status: awareness.status,
      latitude: awareness.latitude,
      longitude: awareness.longitude,
      awareness_intention: awareness.awareness_intention
    }

    # Wrap it in MessageScheme using route
    message = %Bimip.MessageScheme{
      route: 1,  
      payload: {:awareness_notification, notification}
    }

    # Encode the wrapper
    binary = Bimip.MessageScheme.encode(message)

    # Send over WebSocket
    send(state.ws_pid, {:binary, binary})

    {:noreply, state}
  end

  def handle_cast({:processor_subscribe_request, data}, state) do

    msg = Bimip.MessageScheme.decode(data)
    case msg.payload do

      {:subscribe_request,
      %Bimip.SubscribeRequest{
        from: %Bimip.Identity{eid: from_eid, connection_resource_id: _conn_res_id},
        to: %Bimip.Identity{eid: to_eid, connection_resource_id: _conn_res_id},
        subscription_id: subscription_id,
        timestamp: _timestamp,
        one_way: _one_way
      }} ->
        #send the to:GenServer.
        AllRegistry.send_subscriber_to_sender(subscription_id, from_eid, to_eid, data)
        {:noreply, state}
      _ ->
        IO.inspect(msg, label: "Unexpected payload in token revoke")
        {:noreply, state}

    end

  end

  def handle_cast({:processor_subscribe_response, data}, state) do
    msg = Bimip.MessageScheme.decode(data)
    
    case msg.payload do

      {:subscribe_response,
      %Bimip.SubscribeResponse{
        from: %Bimip.Identity{eid: from_eid, connection_resource_id: _conn_res_id},
        to: %Bimip.Identity{eid: to_eid, connection_resource_id: _conn_res_id},
        status: status,
        message: message,
        subscription_id: subscription_id,
        one_way: one_way,
        timestamp: timestamp
      }} ->
        IO.inspect({status, message})
        {:noreply, state}
      _ ->
        IO.inspect(msg, label: "Unexpected payload in token revoke")
        {:noreply, state}

    end
    
  end

  # Terminate device session
  @impl true
  def handle_cast({:processor_terminate_device, {device_id, eid}}, state) do
    AllRegistry.terminate_child_process({eid, device_id})
    {:stop, :normal, state}
  end

end



defmodule DartMessagingServer.Socket do
  @behaviour :cowboy_websocket
  require Logger

  alias App.AllRegistry

  alias Security.TokenVerifier
  alias Util.{ConnectionsHelper, TokenRevoked, PingPongHelper}
  alias Registries.TerminateHandler
  # alias App.AllRegistry

  def init(req, _state) do
    case TokenVerifier.extract_token(:cowboy_req.header("token", req)) do
    {:ok, token} ->  
      case TokenVerifier.verify_token(token) do
        {:error, :token_invoked} -> ConnectionsHelper.reject(req, :token_invoked)
        {:reason, :invalid_token} -> ConnectionsHelper.reject(req, :invalid_token)
        {:ok, claims} -> 
          case TokenRevoked.revoked?(claims["jti"]) do
            false -> 
              IO.inspect({false , claims["jti"]})
              ConnectionsHelper.accept(req, claims)
            true -> 
              IO.inspect({true , claims["jti"]})
              ConnectionsHelper.reject(req,"Token revoked")
          end 
      end
    {:error, :invalid_token} ->  ConnectionsHelper.reject(req, :invalid_token)
    end
  end

  def websocket_init(%{ eid: eid, device_id: device_id} = state) do
    DartMessagingServer.MonitorDynamicSupervisor.start_mother(eid)
    Application.Monitor.start_device(eid, {eid, device_id, self()})
    {:ok, state}
  end

  def websocket_info(:send_ping, state) do
    {:reply, :ping, state}
  end

  def websocket_handle(:pong, %{ eid: _eid, device_id: device_id} = state) do
    now = DateTime.utc_now()
    PingPongHelper.handle_pong_from_network(device_id, now)
    {:ok, state}
  end

  def websocket_info({:custome_binary, binary}, state) do
    Logger.info("Sending awareness frame to client dhbcdsgcvdsbcjhsad jdshvcigdsy")
    send(self(), :terminate_socket)
    {:reply, {:binary, binary}, state}
  end

  def websocket_info(:terminate_socket, state) do
    {:stop, state}
  end

  def websocket_info({:binary, binary}, state) do
    Logger.info("Sending awareness frame to client")
    {:reply, {:binary, binary}, state}
  end

  #send out multiple binaries
  def websocket_info({:binaries, binaries}, state) when is_list(binaries) do
    #send(self(), {:binaries, [bin1, bin2, bin3]})
    Logger.info("Sending batch awareness frames to client")
    frames = Enum.map(binaries, fn bin -> {:binary, bin} end)
    {:reply, frames, state}
  end

  def websocket_handle({:binary, data},  state) do

    if data == <<>> do
      Logger.error("Received empty binary")
      {:ok, state}
    else
      case safe_decode_route(data) do
        {:ok, route} ->
          # Dispatch to the function mapped to this route
          dispatch_map()
          |> Map.get(route, &default_handler/2)
          |> then(fn handler -> handler.(state, data) end)

        {:error, reason} ->
          Logger.error("Failed to decode route: #{inspect(reason)}")
          {:ok, state}
      end
    end
  end

  # Map route numbers to handler functions
  defp dispatch_map do
    %{
      4  => &handle_ping_pong/2,
      5  => &handle_token_revoke_request/2,
      7  => &subscribe_request/2,
      9  => &unsubscribe_request/2,
      11 => &handle_logout/2
    }
  end

  defp handle_ping_pong(state, data) do
    AllRegistry.handle_ping_pong_registry(state, data)
    {:ok, state}
  end

  #check the request type and other data. if not match then report error....
  defp handle_logout(state, data) do
    AllRegistry.handle_handle_logout_registry(state, data)
    {:ok, state}
  end

  defp handle_token_revoke_request(state, data) do
    AllRegistry.handle_token_revoke_request_registry(state, data)
    {:ok, state}
  end

#     send(self(), :terminate_socket)
#     {:reply, {:binary, binary}, state}

# -----------------------
# Handler implementations
# -----------------------
# defp handle_awareness_request(state, data) do
#   msg = Dartmessaging.MessageScheme.decode(data)
#   IO.inspect(msg.payload, label: "AwarenessRequest payload")
#   # Send payload to GenServer for processing
#   # GenServer.cast(PayloadProcessor, {:process_awareness_request, msg.payload, device_id, eid})
# end




# defp handle_subscriber_add_request(state, data) do
#   msg = Dartmessaging.MessageScheme.decode(data)
#   IO.inspect(msg.payload, label: "TokenRevoke payload")
#   # GenServer.cast(PayloadProcessor, {:process_token_revoke, msg.payload, device_id, eid})
# end


defp default_handler(%{ eid: eid, device_id: device_id} = state, data) do
  Logger.error("Unknown route received for device #{device_id}, eid #{eid}")
  {:ok, state}
end

  # -----------------------
  # Only decode the route field for fast dispatch
  # -----------------------
  defp safe_decode_route(data) do
    try do
      msg = Bimip.MessageScheme.decode(data)
      {:ok, msg.route}
    rescue
      e -> {:error, e}
    end
  end

  #terminate, send offline message.......
  def terminate(reason, _req, state) do
    TerminateHandler.handle_terminate(reason, state)
    :ok
  end

end


# validate incoming data eid and device_id,
# validate message sattus agains the chanenl
# validate message tag
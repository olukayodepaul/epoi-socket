defmodule DartMessagingServer.Socket do
  @behaviour :cowboy_websocket
  require Logger
  require Dartmessaging.UserContactList
  
  alias Security.TokenVerifier
  alias Util.{ConnectionsHelper, TokenRevoked, PingPongHelper}

  def init(req, _state) do
    case TokenVerifier.extract_token(:cowboy_req.header("token", req)) do
    {:ok, token} ->  
      case TokenVerifier.verify_token(token) do
        {:error, :token_invoked} -> ConnectionsHelper.reject(req, :token_invoked)
        {:reason, :invalid_token} -> ConnectionsHelper.reject(req, :invalid_token)
        {:ok, claims} -> 
          case TokenRevoked.revoked?(claims["jti"]) do
            false -> ConnectionsHelper.accept(req, claims)
            true -> ConnectionsHelper.reject(req,"Token revoked")
          end 
      end
    {:error, :invalid_token} ->  ConnectionsHelper.reject(req, :invalid_token)
    end
  end

  def websocket_init(state = {:new,{eid, device_id}}) do
    DartMessagingServer.MonitorDynamicSupervisor.start_mother(eid)
    Application.Monitor.start_device(eid, {eid, device_id, self()})
    {:ok, state}
  end

  def websocket_info(:send_ping, state) do
    Logger.info("Sending ping frame to client")
    {:reply, :ping, state}
  end

  def websocket_handle(:pong, {:new,{_eid, device_id}} = state) do
    PingPongHelper.handle_pong(device_id, state)
  end

  def websocket_handle({:binary, data}, state) do
    case Dartmessaging.UserContactList.decode(data) do
      %Dartmessaging.UserContactList{device_id: device_id} = data ->
        Logger.debug("Routing presence message to eid=#{device_id}")
          case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
          [{pid, _}] ->
            GenServer.cast(pid, {:add_contact_list, data})
          [] ->
            Logger.warning("No registry entry for #{device_id}, cannot maybe_start_mother")
          end
        {:ok, state}
      _ ->
        Logger.warning("Invalid presence message received")
        {:ok, state}
    end
  end

  def terminate(reason, _req, state) do
    Registries.TerminateHandler.handle_terminate(reason, state)
  end

end


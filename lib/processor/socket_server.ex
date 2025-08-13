defmodule DartMessagingServer.Socket do
  @behaviour :cowboy_websocket
  require Logger

  alias Util.{Ping, TerminateHandler, Connections, TokenRevoked}
  alias Security.TokenVerifier

  def init(req, _state) do
    case TokenVerifier.extract_token(:cowboy_req.header("token", req)) do
    {:ok, token} ->  
      case TokenVerifier.verify_token(token) do
        {:error, :token_invoked} -> Connections.reject(req, :token_invoked)
        {:reason, :invalid_token} -> Connections.reject(req, :invalid_token)
        {:ok, claims} -> 
          case TokenRevoked.revoked?(claims["jti"]) do
            false -> Connections.accept(req, claims)
            true -> Connections.reject(req,"Token revoked")
          end 
      end
    {:error, :invalid_token} ->  Connections.reject(req, :invalid_token)
    end
  end

  def websocket_init(state = {:new,{eid, device_id}}) do
    DartMessagingServer.DynamicSupervisor.start_session({eid, device_id, self()})
    {:ok, state}
  end

  def websocket_info(:send_ping, state) do
    Logger.info("Sending ping frame to client")
    {:reply, :ping, state}
  end

  def websocket_handle(:pong, {:new,{_eid, device_id}} = state) do
    Ping.handle_pong(device_id, state)
  end

  def terminate(reason, _req, state) do
    TerminateHandler.handle_terminate(reason, state)
  end

end


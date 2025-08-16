defmodule DartMessagingServer.Socket do
  @behaviour :cowboy_websocket
  require Logger

  # alias Util.{
  #   PingPongHelper, 
  #   TerminateHandler, 
  #   ConnectionsHelper, 
  #   TokenRevoked
  # }
  
  alias Security.TokenVerifier
  alias Util.ConnectionsHelper
  alias Util.TokenRevoked
  alias Util.PingPongHelper

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

  def terminate(reason, _req, state) do
    IO.inspect("GenServer Terminated Pass 1")
    IO.inspect(state)
    Registries.TerminateHandler.handle_terminate(reason, state)
  end

end


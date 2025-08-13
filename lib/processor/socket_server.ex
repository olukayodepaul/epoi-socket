defmodule DartMessagingServer.Socket do
  @behaviour :cowboy_websocket
  require Logger

  alias Util.{Ping, TerminateHandler, Connections, TokenRevoked}
  alias Security.TokenVerifier

  def init(req, _state) do

    IO.inspect(TokenVerifier.verify_from_header(:cowboy_req.header("token", req)))
    case TokenVerifier.verify_from_header(:cowboy_req.header("token", req)) do
      {:error, :signature_error} ->  Connections.reject_connection(req,"signature error")
      {:error, reason} -> Connections.reject_connection(req,"#{reason[:message]} #{reason[:claim]}")
      {:ok, claims} -> 
        case TokenRevoked.revoked?(claims["jti"]) do
          false -> Connections.accept_connection(req, claims)
          true -> Connections.reject_connection(req,"Token revoked")
        end 
    end
  end

  def websocket_init(state = {:new,{eid, device_id, conn_time, ip}}) do
    DartMessagingServer.DynamicSupervisor.start_session({eid, device_id, conn_time, ip, self()})
    {:ok, state}
  end

  def websocket_info(:send_ping, state) do
    Logger.info("Sending ping frame to client")
    {:reply, :ping, state}
  end

  def websocket_handle(:pong, {:new,{_eid, device_id, _conn_time, _ip}} = state) do
    Ping.handle_pong(device_id, state)
  end

  def terminate(reason, _req, state) do
    TerminateHandler.handle_terminate(reason, state)
  end


end


defmodule DartMessagingServer.Socket do
  @behaviour :cowboy_websocket
  require Logger

  alias Util.{Ping, TerminateHandler, Connections, TokenRevoked}
  alias Security.TokenVerifier

  # Called when HTTP request matches this route and upgrades to WebSocket
  def init(req, _state) do

    case TokenVerifier.token_verification(:cowboy_req.header("token", req)) do
    {:ok, claims} ->
      IO.inspect(claims["jti"])
      case TokenRevoked.revoked?(claims["jti"]) do
        false -> #what happen next goes here
        true -> Connections.reject_connection(req, "Token Revoked")
      end
      {:ok , req, nil}
    {:error, reason} -> Connections.reject_connection(req, reason)
    _ -> Connections.reject_connection(req, "invalid token")
    end

    # eid = "1"
    # device_id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    # ip = "0.0.3.1"

    # state = {eid, device_id, ip}
    # IO.inspect("0 :init -> upgrading to websocket")
    # {:cowboy_websocket, req, {:new, state}}

  end

  def websocket_init(state = {:new,{eid, device_id, ip}}) do
    DartMessagingServer.DynamicSupervisor.start_session({eid, device_id, ip, self()})
    {:ok, state}
  end

  def websocket_info(:send_ping, state) do
    Logger.info("Sending ping frame to client")
    {:reply, :ping, state}
  end

  def websocket_handle(:pong, {:new,{_eid, device_id, _ip}} = state) do
    Ping.handle_pong(device_id, state)
  end

  def terminate(reason, _req, state) do
    TerminateHandler.handle_terminate(reason, state)
  end


end


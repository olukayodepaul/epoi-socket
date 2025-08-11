defmodule DartMessagingServer.Socket do
  @behaviour :cowboy_websocket
  require Logger

  alias Util.{Ping, TerminateHandler}

  # Called when HTTP request matches this route and upgrades to WebSocket
  def init(req, _state) do

    _token = :cowboy_req.header("token", req)
    _type = :cowboy_req.header("type", req)

    eid = "1"
    device_id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    ip = "0.0.3.1"

    state = {eid, device_id, ip}
    IO.inspect("0 :init -> upgrading to websocket")
    {:cowboy_websocket, req, {:new, state}}
  end

  # Called right after the WebSocket connection is established
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
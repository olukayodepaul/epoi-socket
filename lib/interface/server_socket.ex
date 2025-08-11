defmodule DartMessagingServer.Socket do
  @behaviour :cowboy_websocket

  # Called when HTTP request matches this route and upgrades to WebSocket
  def init(req, state) do

    _token = :cowboy_req.header("token", req)
    _type = :cowboy_req.header("type", req)

    IO.inspect("0 :init -> upgrading to websocket")
    {:cowboy_websocket, req, state}
  end

  # Called right after the WebSocket connection is established
  def websocket_init(_state) do
    eid = "1"
    device_id = "2245"
    ip = "0.0.3.1"
    DartMessagingServer.DynamicSupervisor.start_session({eid, device_id, ip, self()})
    {:ok, {}}
  end

end
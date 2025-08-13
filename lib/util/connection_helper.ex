defmodule Util.Connections do

  require Logger

  def reject_connection(req, reason) do
    Logger.warning("#{inspect(reason)}")
    headers = response_header({401 ,reason, "disconnected"} )
    res = :cowboy_req.reply(401, headers, <<>>, req)
    {:ok, res, nil}
  end

  def accept_connection(req, claims) do
    opts = %{idle_timeout: 60_000}
    {{ip1, ip2, ip3, ip4}, port} = :cowboy_req.peer(req)
    conn_time = :erlang.system_time(:millisecond)
    user_agent = :cowboy_req.header("user-agent", req)
    host = :cowboy_req.host(req)

    req_header = %{
      "x-ip" => "#{ip1}.#{ip2}.#{ip3}.#{ip4}", 
      "x-port" => "#{port}", 
      "x-connection_time" => "#{conn_time}", 
      "x-user_agent" => "#{user_agent}", 
      "x-host" => "#{host}", 
      "x-connection" => "connected",
      "content-type" => "application/json"
    }

    state = {:new,{claims["eid"], claims["device_id"], conn_time, "#{ip1}.#{ip2}.#{ip3}.#{ip4}"}}
    {:cowboy_websocket, :cowboy_req.set_resp_headers(req_header, req) , state ,opts}
  end

  defp response_header({status, message, connection}) do
  %{
      "content-type" => "application/json",
      "x-status" => Integer.to_string(status),
      "x-connection" => to_string(connection),
      "x-message" => to_string(message)
    }
  end

end
defmodule Util.Connections do

  require Logger

  def reject_connection(req, reason) do
    Logger.warning("#{inspect(reason)}")
    headers = response_header({401 ,reason, "disconnected"} )
    res = :cowboy_req.reply(401, headers, <<>>, req)
    {:ok, res, nil}
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
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

  def websocket_info({:binary, binary}, state) do
    Logger.info("Sending awareness frame to client")
    {:reply, {:binary, binary}, state}
  end

  def websocket_handle({:binary, data}, {:new, {_eid, device_id}} = state) do
    if data == <<>> do
      Logger.error("Received empty binary")
      send_error(device_id, 0, "Empty message received", "No route")
      {:ok, state}
    else
      case safe_decode(Dartmessaging.MessageScheme, data) do
        false ->
          Logger.error("Failed to decode MessageScheme")
          send_error(device_id, 400, "Failed to decode MessageScheme", "unknown")
          {:ok, state}

        %Dartmessaging.MessageScheme{route: route, payload: payload} ->
          # Dispatch based on route
          dispatch_map()
          |> Map.get(route, &default_handler/2)
          |> then(fn handler -> handler.(payload, device_id) end)

          {:ok, state}
      end
    end
  end

  # --------------------------
  # Define the dispatch map: route_number => handler_function
  defp dispatch_map do
    %{
      1 => &handle_awareness_notification/2,
      2 => &handle_awareness_response/2
    }
  end

  # --------------------------
  # Handler implementations
  defp handle_awareness_notification({:awareness_notification, notif}, device_id) do
    AllRegistry.handle_awareness_notification(notif, device_id)
  end

  defp handle_awareness_response({:awareness_response, resp}, device_id) do
    AllRegistry.handle_awareness_response(resp, device_id)
  end

  # Default handler for unknown or invalid payloads
  defp default_handler(_payload, device_id) do
    Logger.error("Unknown or invalid payload received")
    send_error(device_id, 422, "Invalid payload or unknown route", "unknown")
  end

  # --------------------------
  # Send structured ErrorMessage back
  defp send_error(device_id, code, message, route, details \\ "") do
    error_msg = %Dartmessaging.ErrorMessage{
      code: code,
      message: message,
      route: route,
      details: details
    }

    message = %Dartmessaging.MessageScheme{
      route: 0,  # Use 0 or reserved route for errors
      payload: {:error_message, error_msg}
    }

    WebSocketServer.send(device_id, message)
  end

  # --------------------------
  defp safe_decode(module, data) do
    try do
      module.decode(data)
    rescue
      e ->
        Logger.debug("Decode error for #{inspect(module)}: #{inspect(e)}")
        false
    end
  end

  #terminate, send offline message.......
  def terminate(reason, _req, state) do
    TerminateHandler.handle_terminate(reason, state)
    :ok
  end

end


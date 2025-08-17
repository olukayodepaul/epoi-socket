defmodule Registries.TerminateHandler do
  require Logger

  @doc """
  Handles cleanup and logging when a WebSocket terminates.
  """
  def handle_terminate(reason, {:new,{_eid, device_id}}) do
    Logger.info("WebSocket terminated for #{device_id}, reason: #{inspect(reason)}")
    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] ->
        GenServer.cast(pid, :terminate_device)
      [] ->
        Logger.warning("No registry entry for #{device_id}, cannot maybe_start_mother")
    end
    Logger.warning("No Application.Processor found for #{device_id} during websocket terminate")
    log_reason(reason, device_id)
    :ok
  end

  def handle_terminate(reason, state) do
    IO.inspect("GenServer Terminated Pass 2B")
    Logger.info("WebSocket terminated with reason: #{inspect(reason)}")
    log_reason(reason, extract_registry_id(state))
    :ok
  end

  ## --- Private helpers ---

  defp log_reason(:normal, device_id) do
    Logger.info("Clean WebSocket close for #{inspect(device_id)}")
  end

  defp log_reason({:remote, :closed}, device_id) do
    Logger.warning("Remote peer closed TCP connection for #{inspect(device_id)}")
  end

  defp log_reason({:shutdown, _} = shutdown_reason, device_id) do
    Logger.warning("WebSocket shutdown for #{inspect(device_id)}: #{inspect(shutdown_reason)}")
  end

  defp log_reason({:tcp_closed, _} = tcp_close_reason, device_id) do
    Logger.warning("TCP connection closed for #{inspect(device_id)}: #{inspect(tcp_close_reason)}")
  end

  defp log_reason(other, device_id) do
    Logger.error("Unexpected terminate reason for #{inspect(device_id)}: #{inspect(other)}")
  end

  defp extract_registry_id({:new, {device_id, _, _, _}}), do: device_id
  defp extract_registry_id(_), do: :unknown
end

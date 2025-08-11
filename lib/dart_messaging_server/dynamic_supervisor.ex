defmodule DartMessagingServer.DynamicSupervisor do
  use DynamicSupervisor
  require Logger

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_session({any, any, any, pid}) :: {:ok, pid} | {:error, any}
  def start_session({_eid, device_id, _ip, _ws_pid} = state) do
    child_spec = %{
      id: {:connection_session, device_id},
      start: {Application.Processor, :start_link, [state]},
      restart: :transient,
      shutdown: 5000
    }

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        Logger.info("Session started for #{inspect(device_id)}")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.warning("Session already started for #{inspect(device_id)}")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start session for #{inspect(device_id)}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end

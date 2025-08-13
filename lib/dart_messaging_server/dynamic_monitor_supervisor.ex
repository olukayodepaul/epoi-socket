defmodule DartMessagingServer.MonitorDynamicSupervisor do
  use Horde.DynamicSupervisor
  require Logger

  def start_link(_args) do
    Horde.DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    Horde.DynamicSupervisor.init(
      strategy: :one_for_one,
      members: :auto
    )
  end

  @spec start_mother(any) :: {:ok, pid} | {:error, any}
  def start_mother(user_id) do
    child_spec = %{
      id: {:mother_session, user_id},
      start: {Application.Monitor, :start_link, [user_id]},
      restart: :transient,
      shutdown: 5000
    }

    case Horde.DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        Logger.info("Mother process started for user_id=#{inspect(user_id)}, pid=#{inspect(pid)}")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.warning("Mother process already running for user_id=#{inspect(user_id)}, pid=#{inspect(pid)}")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start Mother process for user_id=#{inspect(user_id)}. Reason: #{inspect(reason)}")
        {:error, reason}
    end
  end
end

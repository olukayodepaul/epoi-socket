defmodule DartMessagingServer.MonitorDynamicSupervisor do
  use Horde.DynamicSupervisor
  require Logger

  @moduledoc """
  Dynamic supervisor for all Mother processes (per user).
  """

  def start_link(_args) do
    Horde.DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    Horde.DynamicSupervisor.init(strategy: :one_for_one, members: :auto)
  end

  @spec start_mother(eid :: any()) :: {:ok, pid} | {:error, any()}
  def start_mother(eid) do
    case Horde.Registry.lookup(UserRegistry, eid) do
      [{pid, _value}] ->
        Logger.info("Mother already running for eid=#{eid}, pid=#{inspect(pid)}")
        {:ok, pid}

      [] ->
        child_spec = %{
          id: {:mother_session, eid},
          start: {Application.Monitor, :start_link, [eid]},
          restart: :transient,
          shutdown: 5000
        }

        case Horde.DynamicSupervisor.start_child(__MODULE__, child_spec) do
          {:ok, pid} ->
            Logger.info("Mother started for eid=#{eid}, pid=#{inspect(pid)}")
            {:ok, pid}

          {:error, reason} ->
            Logger.error("Failed to start Mother for eid=#{eid}, reason=#{inspect(reason)}")
            {:error, reason}
        end
    end
  end
end

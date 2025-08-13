defmodule Application.Monitor do
  use GenServer
  require Logger

  alias Util.RegistryHelper

  def start_link(user_id) do
    GenServer.start_link(__MODULE__, user_id, name: RegistryHelper.via_monitor_registry(user_id))
  end

  def init(user_id) do
    Logger.info("MotherServer init for user_id=#{user_id}")
    {:ok, %{user_id: user_id, devices: %{}}}
  end

end

defmodule   Application.Processor  do
  use GenServer
  require Logger
  alias Util.RegistryHelper
  alias Util.PingPongHelper
  alias App.AllRegistry
  alias  Transports.AppPresence
  # alias Dartmessaging.PresenceSubscription

  @moduledoc """
  Child session process representing a device.
  Dies if socket disconnects.
  """

  def start_link({_eid, device_id, _ws_pid} = state) do
    GenServer.start_link(__MODULE__, state, name: RegistryHelper.via_registry(device_id))
  end

  @impl true
  def init({eid, device_id, ws_pid}) do
    PingPongHelper.schedule_ping(device_id)
    AllRegistry.set_startup_status({eid, device_id, ws_pid})
    {:ok, %{missed_pongs: 0, eid: eid, device_id: device_id, ws_pid: ws_pid}}
  end

  #Socket to processor
  @impl true
  def handle_cast(:processor_terminate_device,  %{device_id: device_id, eid: eid} = state) do
    AllRegistry.terminate_child_process({eid, device_id})
    {:stop, :normal, state}
  end

  def handle_cast({:processor_get_all_subcriber, {device_id, owner_eid, subscribers}}, state) do
    friends = Enum.map(subscribers, & &1.subscriber_eid)
    subscription = %Model.PresenceSubscription{
      owner: owner_eid,
      device_id: device_id,
      friends: friends
    }
    AppPresence.subscriptions(subscription)
    {:noreply, state}
  end

  @impl true
  def handle_info(:send_ping, state), do: PingPongHelper.handle_ping(state)
  def handle_info(:received_pong, state), do: {:noreply, PingPongHelper.reset_pongs(state)}

  
 
  # def handle_info({:presence_update, %PresenceSubscription{} = friend_presence}, state) do
  #   IO.inspect(friend_presence, label: "Received friend presence")
  #   {:noreply, state}
  # end

end

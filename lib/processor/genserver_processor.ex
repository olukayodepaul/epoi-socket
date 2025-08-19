defmodule   Application.Processor  do
  use GenServer
  require Logger
  alias Util.RegistryHelper
  alias Util.PingPongHelper
  alias App.AllRegistry
  alias  Followers.AddSubscribers

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

  #terminate device
  @impl true
  def handle_cast(:terminate_device,  %{device_id: device_id, eid: eid} = state) do
    AllRegistry.terminate_child_process({eid, device_id})
    {:stop, :normal, state}
  end

  @impl true
  def handle_cast({:add_contact_list, %Dartmessaging.UserContactList{} = data}, state) do
    IO.inspect({"Reactive", data})
    AddSubscribers.add_friends_subscriptions(data)
    {:noreply, state}   # Correct return value for handle_cast
  end

  @impl true
  def handle_info(:send_ping, state), do: PingPongHelper.handle_ping(state)
  def handle_info(:received_pong, state), do: {:noreply, PingPongHelper.reset_pongs(state)}

  def handle_info({:presence_update, user_contact}, state) do
    IO.inspect("Genserver receive the presence update")
    # case :ets.lookup(:presence_table, user_contact.eid) do
    #   [{_eid, old_contact}] ->
    #     if presence_changed?(user_contact, old_contact) do
    #       :ets.insert(:presence_table, {user_contact.eid, user_contact})
    #       broadcast_to_subscribers(user_contact)
    #     end

    #   [] ->
    #     # first time seeing this user
    #     :ets.insert(:presence_table, {user_contact.eid, user_contact})
    #     broadcast_to_subscribers(user_contact)
    # end
    {:noreply, state}
  end

  

end

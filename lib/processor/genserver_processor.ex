defmodule Application.Processor do
  use GenServer
  require Logger
  alias Util.{RegistryHelper, PingPongHelper}
  alias App.AllRegistry
  alias Bicp.AppPresence
  alias Storage.LocalSubscriberCache
  alias Strucs.Awareness


  @moduledoc """
  Child session process representing a device.
  Dies if socket disconnects.
  """

  # Start GenServer for device session
  def start_link({_eid, device_id, _ws_pid} = state) do
    GenServer.start_link(__MODULE__, state, name: RegistryHelper.via_registry(device_id))
  end

  @impl true
  def init({eid, device_id, ws_pid}) do
    LocalSubscriberCache.init(device_id)
    AllRegistry.set_startup_status({eid, device_id, ws_pid})
    PingPongHelper.schedule_ping(device_id)
    {:ok, %{missed_pongs: 0, pong_counter: 0, timer: DateTime.utc_now(), eid: eid, device_id: device_id, ws_pid: ws_pid}}
  end

  # Terminate device session
  @impl true
  def handle_cast(:processor_terminate_device, %{device_id: device_id, eid: eid} = state) do
    AllRegistry.terminate_child_process({eid, device_id})
    :ets.delete(LocalSubscriberCache.table_name(device_id)) # put this in the right file
    {:stop, :normal, state}
  end

  # Handle subscription request from client
  def handle_cast({:processor_get_all_subcriber, {device_id, owner_eid, subscribers}}, state) do
    friends = Enum.map(subscribers, & &1.subscriber_eid)
    subscription = %Awareness{
      owner_eid: owner_eid,
      device_id: device_id,
      friends: friends,
      status: "ONLINE",
      last_seen: DateTime.utc_now() |> DateTime.to_unix(),

    }
    AppPresence.subscriptions(subscription)
    {:noreply, state}
  end

  # Handle awareness update from client
  # This is where we need the sever response on the awareness. to send either
  def handle_cast({:processor_awareness, awareness},  state) do
    AppPresence.apply_awareness(awareness)
    {:noreply, state}
  end

  # Handle ping/pong
  @impl true
  def handle_info(:send_ping, state), do: PingPongHelper.handle_ping(state)
  def handle_info(:received_pong, state), do: {:noreply, PingPongHelper.reset_pongs(state)}

  def handle_info({:awareness_update, %Strucs.Awareness{} = awareness}, %{eid: eid} = state) do
    if String.downcase(awareness.status) == "online" do
        response = %Dartmessaging.Awareness{
          from: "#{awareness.owner_eid}/#{awareness.device_id}",
          last_seen: awareness.last_seen,
          status: awareness.status,
          latitude: awareness.latitude,
          longitude: awareness.longitude
        }
        binary = Dartmessaging.Awareness.encode(response)
        send(state.ws_pid, {:binary, binary})
        AllRegistry.send_subscriber_last_seen_to_monitor({awareness.owner_eid, eid, awareness.device_id, awareness.status})
      end
      {:noreply, state}
  end

end

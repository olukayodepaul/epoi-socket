defmodule Application.Processor do
  use GenServer
  require Logger
  alias Util.RegistryHelper
  alias Util.PingPongHelper
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
    PingPongHelper.schedule_ping(device_id)
    AllRegistry.set_startup_status({eid, device_id, ws_pid})
    LocalSubscriberCache.init(device_id)

    {:ok, %{missed_pongs: 0, eid: eid, device_id: device_id, ws_pid: ws_pid}}
  end

  # Terminate device session
  @impl true
  def handle_cast(:processor_terminate_device, %{device_id: device_id, eid: eid} = state) do
    AllRegistry.terminate_child_process({eid, device_id})
    :ets.delete(LocalSubscriberCache.table_name(device_id))
    {:stop, :normal, state}
  end

  # Handle subscription request from client
  def handle_cast({:processor_get_all_subcriber, {device_id, owner_eid, subscribers}}, state) do
    friends = Enum.map(subscribers, & &1.subscriber_eid)

    subscription = %Awareness{
      owner_eid: owner_eid,
      device_id: device_id,
      friends: friends,
      status: :ONLINE,
      last_seen: DateTime.utc_now() |> DateTime.to_unix()
    }
    AppPresence.subscriptions(subscription)
    {:noreply, state}
  end

  # Handle awareness update from client
  def handle_cast({:processor_awareness, awareness},  state) do
    AppPresence.apply_awareness(awareness)
    {:noreply, state}
  end

  # Handle ping/pong
  @impl true
  def handle_info(:send_ping, state), do: PingPongHelper.handle_ping(state)
  def handle_info(:received_pong, state), do: {:noreply, PingPongHelper.reset_pongs(state)}

  def handle_info({:awareness_update, %Strucs.Awareness{} = awareness}, state) do

    response = %Dartmessaging.Awareness{
      from: "#{awareness.owner_eid}/#{awareness.device_id}",
      last_seen: awareness.last_seen,
      status: awareness.status,
      latitude: awareness.latitude || 0.0,
      longitude: awareness.longitude || 0.0
    }

    binary = Dartmessaging.Awareness.encode(response)
    send(state.ws_pid, {:binary, binary})
    {:noreply, state}
  end


end

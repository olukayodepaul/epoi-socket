defmodule Application.Processor do
  use GenServer
  require Logger
  alias Util.{RegistryHelper, PingPongHelper}
  alias App.AllRegistry

  # Start GenServer for device session
  def start_link({_eid, device_id, _ws_pid} = state) do
    GenServer.start_link(__MODULE__, state, name: RegistryHelper.via_registry(device_id))
  end

  @impl true
  def init({eid, device_id, ws_pid}) do
    AllRegistry.setup_client_init({eid, device_id, ws_pid}) # pass
    PingPongHelper.schedule_ping(device_id)
    {:ok, %{missed_pongs: 0, pong_counter: 0, timer: DateTime.utc_now(), eid: eid, device_id: device_id, ws_pid: ws_pid}}
  end

  # Handle ping/pong
  @impl true
  def handle_info(:send_ping, state), do: PingPongHelper.handle_ping(state)
  def handle_cast(:received_pong, state), do: {:noreply, PingPongHelper.reset_pongs(state)}

  # Terminate device session
  @impl true
  def handle_cast({:processor_terminate_device, {device_id, eid}}, state) do
    # AllRegistry.terminate_child_process({eid, device_id})
    {:stop, :normal, state}
  end

  def handle_cast({:fan_out_to_children, {owner_device_id, eid, awareness}},   state) do
    # IO.inspect({eid, awareness,  owner_device_id })

    response = %Dartmessaging.Awareness{
      from: "#{awareness.owner_eid}",
      last_seen: DateTime.to_unix(awareness.last_seen, :second) ,
      status: awareness.status,
      latitude: awareness.latitude,
      longitude: awareness.longitude,
    }

    binary = Dartmessaging.Awareness.encode(response)
    send(state.ws_pid, {:binary, binary})
    {:noreply, state}

  end


end

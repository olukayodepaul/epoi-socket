defmodule PingPongTest do
  @moduledoc """
  Simulates a device going ONLINE → OFFLINE → ONLINE
  based on missed pings and state change logic.
  """

  # -------------------------
  # Mock registry to capture notifications
  # -------------------------
  defmodule MockRegistry do
    def send_pong_to_server(device_id, eid, status) do
      IO.puts("[MockRegistry] Device #{device_id} of #{eid} changed state to #{status}")
    end

    def schedule_ping_registry(_device_id, interval) do
      IO.puts("[MockRegistry] Scheduling next ping in #{interval} ms")
    end
  end

  # -------------------------
  # Run the simulation
  # -------------------------
  def run_simulation do
    Application.put_env(:dart_messaging_server, :all_registry_module, MockRegistry)

    # Initial device state
    state = %{
      eid: "a@domain.com",
      device_id: "aaaaa1",
      ws_pid: self(),
      timer: DateTime.utc_now(),
      pong_counter: 0,
      missed_pongs: 0,
      last_state_change: DateTime.utc_now(),
      last_rtt: nil,
      max_missed_pongs_adaptive: 3,
      last_send_ping: DateTime.utc_now()
    }

    IO.puts("Simulating missed pings → device goes OFFLINE")

    # Step 1: Simulate missed pings to trigger OFFLINE
    state = Enum.reduce(1..10, state, fn tick, st ->
      IO.puts("\nTick #{tick} (missed ping)")
      {:noreply, st2} = Util.PingPongHelper.handle_ping(st)
      st2
    end)

    IO.inspect(state, label: "Device state after missed pings")

    # Step 2: Simulate pong received → device comes ONLINE
    # IO.puts("\nSimulating pong received → device ONLINE")
    # {:noreply, state} = Util.PingPongHelper.pongs_received(
    #   state.device_id,
    #   DateTime.utc_now(),
    #   state
    # )

    # IO.inspect(state, label: "Device state after pong received")

    state
  end
end


# run the project
# iex -S mix
# c("lib/test/ping_pong_test.exs")
# PingPongTest.run_simulation()

c("lib/test/proto_test.exs")
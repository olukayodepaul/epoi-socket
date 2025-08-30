# Convert hex string to actual binary
defmodule ProtoTest do

  def test() do

    binary =
      "
      08 01 12 26 0A 0C 62 40 64 6F 6D 61 69 6E 2E 63 
      6F 6D 12 0C 61 40 64 6F 6D 61 69 6E 2E 63 6F 6D 
      18 01 20 DC 81 CB C5 06 38 01 
      "
      |> String.split()                 # split by spaces
      |> Enum.map(&String.to_integer(&1, 16))  # convert each hex to integer
      |> :binary.list_to_bin()          # convert list of integers to binary

    # Decode with MessageScheme
    message = Dartmessaging.MessageScheme.decode(binary)

    # Inspect the route and payload
    IO.puts("Route: #{message.route}")

    case message.payload do
      {:awareness_notification, notif} ->
        IO.inspect(notif, label: "AwarenessNotification")

      {:awareness_response, resp} ->
        IO.inspect(resp, label: "AwarenessResponse")

      _ ->
        IO.puts("Unknown payload type")
    end
  end

end
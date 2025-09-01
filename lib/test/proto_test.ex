defmodule ProtoTest do
  def test() do
    binary =
      "
      08 01 12 26 0A 0C 61 40 64 6F 6D 61 69 6E 2E 63
      6F 6D 12 0C 63 40 64 6F 6D 61 69 6E 2E 63 6F 6D
      18 01 20 F3 93 D3 C5 06 38 02
      "
      |> String.split()
      |> Enum.map(&String.to_integer(&1, 16))
      |> :binary.list_to_bin()

    # Decode with MessageScheme
    message = Dartmessaging.MessageScheme.decode(binary)

    IO.puts("Route: #{message.route}")

    # Extract payload safely
    case message.payload do
      {:awareness_notification, notif} ->
        IO.inspect(notif, label: "AwarenessNotification")

      {:awareness_response, resp} ->
        IO.inspect(resp, label: "AwarenessResponse")

      other ->
        IO.inspect(other, label: "Unknown payload")
    end
  end
end

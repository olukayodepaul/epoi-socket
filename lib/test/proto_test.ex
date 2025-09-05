defmodule ProtoTest do
  def test() do
    binary =
      "
      08 01 12 2A 0A 0E 0A 0C 62 40 64 6F 6D 61 69 6E
      2E 63 6F 6D 12 0E 0A 0C 61 40 64 6F 6D 61 69 6E
      2E 63 6F 6D 18 04 20 E5 BC E8 C5 06 38 02 
      "
      |> String.split()
      |> Enum.map(&String.to_integer(&1, 16))
      |> :binary.list_to_bin()

    # Decode with MessageScheme
    message = Bimip.MessageScheme.decode(binary)

    IO.inspect(message, label: "")

  end
end

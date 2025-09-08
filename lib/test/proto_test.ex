defmodule ProtoTest do
  def test() do
    binary =
      "
      08 06 32 3B 0A 16 0A 0C 61 40 64 6F 6D 61 69 6E
      2E 63 6F 6D 12 06 61 61 61 61 61 31 10 02 18 F1 
      BB 94 A1 91 33 20 80 A0 B8 A1 92 33 2A 11 65 72
      67 66 79 65 72 68 66 6A 65 72 68 67 75 65 72 
      "
      |> String.split()
      |> Enum.map(&String.to_integer(&1, 16))
      |> :binary.list_to_bin()

    # Decode with MessageScheme
    message = Bimip.MessageScheme.decode(binary)

    IO.inspect(message, label: "")

  end
end


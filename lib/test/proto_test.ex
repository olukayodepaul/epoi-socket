defmodule ProtoTest do
  def test() do
    binary =
      "
      08 07 3A 47 0A 0E 0A 0C 64 40 64 6F 6D 61 69 6E
      2E 63 6F 6D 12 0E 0A 0C 61 40 64 6F 6D 61 69 6E
      2E 63 6F 6D 18 01 22 10 75 73 65 72 20 69 6E 66 
      6F 72 6D 61 74 69 6F 6E 28 FC E1 E6 EE 92 33 32 
      0A 61 6E 63 69 73 64 63 73 61 64 
      "
      |> String.split()
      |> Enum.map(&String.to_integer(&1, 16))
      |> :binary.list_to_bin()

    # Decode with MessageScheme
    message = Bimip.MessageScheme.decode(binary)

    IO.inspect(message, label: "")

  end
end


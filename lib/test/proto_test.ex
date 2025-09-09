defmodule ProtoTest do
  def test() do
    binary =
      "
      08 06 32 33 0A 0E 0A 0C 61 40 64 6F 6D 61 69 6E 
      2E 63 6F 6D 12 0E 0A 0C 64 40 64 6F 6D 61 69 6E
      2E 63 6F 6D 1A 0A 61 6E 63 69 73 64 63 73 61 64
      28 DD C8 F5 EC 92 33
      "
      |> String.split()
      |> Enum.map(&String.to_integer(&1, 16))
      |> :binary.list_to_bin()

    # Decode with MessageScheme
    message = Bimip.MessageScheme.decode(binary)

    IO.inspect(message, label: "")

  end
end


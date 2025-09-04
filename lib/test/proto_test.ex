defmodule ProtoTest do
  def test() do
    binary =
      "
      08 0C 62 23 0A 16 0A 0C 61 40 64 6F 6D 61 69 6E
      2E 63 6F 6D 12 06 61 61 61 61 61 31 10 02 18 03
      20 BC 9E C9 A9 91 33 
      "
      |> String.split()
      |> Enum.map(&String.to_integer(&1, 16))
      |> :binary.list_to_bin()

    # Decode with MessageScheme
    message = Bimip.MessageScheme.decode(binary)


    IO.inspect(message, label: "")

  end
end

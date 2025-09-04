defmodule Util.StatusMapper do
  def to_int(:online), do: 1
  def to_int(:offline), do: 4
  def to_int(_), do: nil  # fallback for unexpected atoms
end



# defmodule PresenceState do
#   @mapping %{
#     online: 1,
#     offline: 2,
#     away: 3,
#     busy: 4,
#     dnd: 5,
#     invisible: 6,
#     idle: 7,
#     unknown: 8
#   }

#   # atom -> int
#   def to_int(state) when is_atom(state), do: Map.get(@mapping, state, nil)

#   # int -> atom
#   def to_atom(code) when is_integer(code) do
#     Enum.find_value(@mapping, fn {key, val} -> if val == code, do: key end)
#   end
# end
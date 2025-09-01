defmodule Mac do

  defmacro so_something(do: block) do
    quote do
      unquote(block)
    end
  end
end


defmodule Rs do

  require Mac

  def ts do
    Mac.so_something do
      y = 6
      m = 6

      r = y + m
      {:ok, r}
    end
  end
end
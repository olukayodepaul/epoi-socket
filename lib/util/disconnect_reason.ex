defmodule Util.DisconnectReason do
  @moduledoc false
  defstruct [:type, :message]

  def missed_pong, do: %__MODULE__{type: :missed_pong, message: "Missed pong timeout"}
  def tcp_closed, do: %__MODULE__{type: :tcp_closed, message: "TCP connection closed"}
  def normal, do: %__MODULE__{type: :normal, message: "Normal disconnect"}
end

defmodule Model.PresenceSubscription do
  defstruct [
    :owner,
    :device_id,
    :friends,
    :online,
    :typing,
    :recording,
    :last_seen
  ]
end

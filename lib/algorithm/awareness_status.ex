# defmodule Algorithm.AwarenessStatus do
#   # This is used to drive awareness of the users.

#     # Broadcast only if state changed
#     defp maybe_broadcast(state) do
#       eid = state.eid
#       state_table = state.state_table

#       # Get current devices
#       devices = Storage.PgDeviceCache.all_by_owner(eid)

#       current_status =
#         if Enum.any?(devices, &(&1.status == @online)), do: :online, else: :offline

#       # Read last broadcasted state
#       last_status =
#         case :ets.lookup(state_table, :last_status) do
#           [{:last_status, s}] -> s
#           _ -> nil
#         end

#       # Only broadcast if changed
#       if last_status != current_status do
#         :ets.insert(state_table, {:last_status, current_status})
#         broadcast_awareness(eid, devices, current_status)
#       end
#     end


# end




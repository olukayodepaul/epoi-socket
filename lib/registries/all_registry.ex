defmodule App.AllRegistry do

  require Logger

  def set_startup_status({eid, device_id, ws_pid}) do
    case Horde.Registry.lookup(UserRegistry, eid) do
      [{pid, _}] ->
        GenServer.cast(pid, {:get_startup_status, %{eid: eid, device_id: device_id, ws_pid: ws_pid }})
      []->
        Logger.warning("No registry entry for #{device_id}, cannot maybe_start_mother")
    end
  end

  def terminate_child_process({eid, device_id}) do
    case Horde.Registry.lookup(UserRegistry, eid) do
    [{pid, _}] ->
      GenServer.cast(pid, {:terminate_child_process, {eid, device_id}})
    [] ->
      Logger.warning("No registry entry for #{device_id}, cannot maybe_start_mother")
    end
  end

  def handle_binary(device_id, tag, decode) do
    IO.inspect(decode)
    IO.inspect(device_id)
    IO.inspect(tag)

    case Horde.Registry.lookup(DeviceIdRegistry, device_id) do
      [{pid, _}] ->
        # Send the struct directly, no extra tuple
        GenServer.cast(pid, {tag, decode})

      [] ->
        Logger.warning("No registry entry for #{device_id}, cannot maybe_start_mother")
    end
  end

end
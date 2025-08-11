## DartMessagingServer

install elixir supervisor project

```js
mix new project-name --sup
```

Look up Registry by eid and device id

```
case lookup_by_device_id("some-device-id") do
  [{pid, _value} | _] ->
    IO.puts("Found process PID: #{inspect(pid)}")
  [] ->
    IO.puts("No process found for device id")
end

case lookup_by_eid(eid) do
  [] ->
    IO.puts("No process found for eid")

  entries ->
    Enum.each(entries, fn {pid, device_id} ->
      IO.puts("Found process PID: #{inspect(pid)} with device_id: #{device_id}")
    end)
end
```

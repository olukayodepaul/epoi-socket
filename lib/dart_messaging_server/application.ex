
defmodule DartMessagingServer.Application do
  use Application
  alias ApplicationServer.Configuration

  @impl true
  def start(_type, _args) do
    cowboy_spec =
      if Configuration.secure?() do
        %{
          id: :https,
          start: {:cowboy, :start_tls, [
            :https,
            [
              port: Configuration.port(),
              certfile: Configuration.certfile(),
              keyfile: Configuration.keyfile()
            ],
            %{env: %{dispatch: dispatch()}}
          ]}
        }
      else
        %{
          id: :http,
          start: {:cowboy, :start_clear,
            [:http, [port: Configuration.port()], %{env: %{dispatch: dispatch()}}]}
        }
      end

    children = [
      cowboy_spec,
      {DartMessagingServer.MonitorDynamicSupervisor, []},
      {DartMessagingServer.DynamicSupervisor, []},
      {Horde.Registry,name: DeviceIdRegistry, keys: :unique, members: :auto},
      {Horde.Registry, name: UserRegistry, keys: :unique, members: :auto},
      {Redix, name: :redix},
    ]
    
    opts = [strategy: :one_for_one, name: DartMessagingServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    :cowboy_router.compile([
      {:_,
      [
        {Configuration.route(), DartMessagingServer.Socket, []}
      ]}
    ])
  end
end

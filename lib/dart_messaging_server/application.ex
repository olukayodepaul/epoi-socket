defmodule DartMessagingServer.Application do
  use Application
  require Logger
  alias ApplicationServer.Configuration

  @impl true
  def start(_type, _args) do
    # Start Mnesia safely
    case :mnesia.start() do
      :ok ->
        Logger.info("✅ Mnesia started successfully")

      {:error, {:already_started, _}} ->
        Logger.info("Mnesia already started")

      other ->
        Logger.error("⚠️ Failed to start Mnesia: #{inspect(other)}")
    end

    # Ensure schema exists (one-time only)
    ensure_schema()

    # Ensure offline subscriptions table exists
    ensure_offline_table()

    cowboy_spec =
      if Configuration.secure?() do
        %{
          id: :https,
          start:
            {:cowboy, :start_tls,
             [
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
          start:
            {:cowboy, :start_clear,
             [:http, [port: Configuration.port()], %{env: %{dispatch: dispatch()}}]}
        }
      end

    children = [
      cowboy_spec,
      {DartMessagingServer.MonitorDynamicSupervisor, []},
      {DartMessagingServer.DynamicSupervisor, []},
      {Horde.Registry, name: DeviceIdRegistry, keys: :unique, members: :auto},
      {Horde.Registry, name: UserRegistry, keys: :unique, members: :auto},
      {Redix, name: :redix},
      {Phoenix.PubSub, name: ApplicationServer.PubSub},
      ApplicationServer.Presence,
      case Configuration.selected_db() do
        :postgres -> App.PgRepo
        :mongo -> {Mongo, Application.get_env(:dart_messaging_server, :mongo)}
      end
    ]

    opts = [strategy: :one_for_one, name: DartMessagingServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # --- Helpers ---

  defp ensure_schema do
    case :mnesia.create_schema([node()]) do
      {:atomic, :ok} ->
        Logger.info("✅ Mnesia schema created")

      {:aborted, {:already_exists, _}} ->
        Logger.info("Mnesia schema already exists")

      {:error, {_, {:already_exists, _}}} ->
        Logger.info("Mnesia schema already exists (error tuple)")

      other ->
        Logger.error("⚠️ Mnesia schema issue: #{inspect(other)}")
    end
  end

  defp ensure_offline_table do
    case :mnesia.table_info(:offline_subscriptions, :attributes) do
      :undefined ->
        case :mnesia.create_table(:offline_subscriptions, [
               {:attributes, [:subscription_id, :from_eid, :to_eid, :payload, :timestamp]},
               {:disc_copies, [node()]},
               {:type, :set},
               {:index, [:to_eid]}
             ]) do
          {:atomic, :ok} ->
            Logger.info("✅ Mnesia table :offline_subscriptions created")

          {:aborted, reason} ->
            Logger.error("⚠️ Failed to create table: #{inspect(reason)}")
        end

      _ ->
        Logger.info("Mnesia table :offline_subscriptions already exists")
    end
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

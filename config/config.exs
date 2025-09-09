import Config

config :dart_messaging_server, :server,
  secure: false, 
  port: 4003,
  certfile: "priv/cert.pem",
  keyfile: "priv/key.pem",
  route: "/application/development",
  sign_alg: "RS256",
  pb_key_file_path: "priv/keys/public.pem",
  idle_timeout: 60_000,
  selected_db: :postgres, #redis #mysql #mongodb
  awareness_topic: "awareness"


config :dart_messaging_server, :network_ping_pong,
  default_ping_interval: 10_000,     # Ping every 10s → light but responsive
  max_allowed_delay: 45,             # Allow up to 45s delay before forcing check
  max_pong_counter: 3,               # Refresh ONLINE every ~30s (3 × 10s)
  initial_adaptive_max_missed: 6     # 6 misses = ~60s silence → OFFLINE

config :dart_messaging_server, :processor_state,
  stale_threshold_seconds: 60 * 20,   # Device considered stale after 2 min without pong
  force_change_seconds: 60 * 10     # Force a rebroadcast every 1 min idle

config :dart_messaging_server, :monitor_state,
  stale_threshold_seconds: 60 * 5,   # 60 * 20 User considered stale after 10 min no device activity
  force_change_seconds: 60 * 15       # Force rebroadcast every 5 min idle


config :dart_messaging_server,
  ecto_repos: [App.PgRepo]

config :dart_messaging_server, App.PgRepo,
  username: "postgres",
  password: "postgres",
  database: "myapp_db",
  hostname: "localhost", # try localhost if this fails
  port: 5432,
  pool_size: 10,
  log: false

# config :dart_messaging_server, App.MySQLRepo,
#   username: "root",
#   password: "password",
#   database: "myapp_db",
#   hostname: "localhost",
#   port: 3306,
#   pool_size: 10

# config :dart_messaging_server, :mongo,
#   name: :mongo,               # the registered name for the connection
#   database: "myapp_db",
#   username: "mongo_user",
#   password: "mongo_pass",
#   hostname: "localhost",
#   port: 27017,
#   pool_size: 10

# Redis config
config :dart_messaging_server, :redis,
  host: "localhost",
  port: 6379,
  name: :redix


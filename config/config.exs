import Config

config :dart_messaging_server, :server,
  secure: false, 
  port: 4003,
  certfile: "priv/cert.pem",
  keyfile: "priv/key.pem",
  route: "/application/development",
  sign_alg: "RS256",
  pb_key_file_path: "priv/keys/public.pem",
  ping_interval: 10_000,
  max_missed_pongs: 3,
  idle_timeout: 60_000,
  selected_db: :postgres, #redis #mysql #mongodb
  awareness_topic: "awareness",
  max_pong_counter: 3

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


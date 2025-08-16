import Config

config :dart_messaging_server, :server,
  secure: false, 
  port: 4003,
  certfile: "priv/cert.pem",
  keyfile: "priv/key.pem",
  route: "/application/development",
  sign_alg: "RS256",
  pb_key_file_path: "priv/keys/public.pem",
  ping_interval: 30_000,
  max_missed_pongs: 3,
  idle_timeout: 60_000
  

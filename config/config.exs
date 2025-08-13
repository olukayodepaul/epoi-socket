import Config

config :dart_messaging_server, :server,
  secure: false, 
  port: 4003,
  certfile: "priv/cert.pem",
  keyfile: "priv/key.pem",
  route: "/application/development",
  sign_alg: "RS256",
  pb_key_file_path: "priv/keys/public.pem"

  
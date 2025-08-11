import Config

config :dart_messaging_server, :server,
  secure: false,
  port: 4001,
  certfile: "priv/cert.pem",
  keyfile: "priv/key.pem",
  route: "/application/development"
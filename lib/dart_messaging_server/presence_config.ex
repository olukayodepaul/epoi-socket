defmodule DartMessagingServer.Presence do
  use Phoenix.Presence,
    otp_app: :dart_messaging_server,
    pubsub_server: DartMessagingServer.PubSub
end
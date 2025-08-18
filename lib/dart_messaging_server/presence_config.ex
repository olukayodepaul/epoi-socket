defmodule ApplicationServer.Presence do
  use Phoenix.Presence,
    otp_app: :application_server,
    pubsub_server: ApplicationServer.PubSub
end
defmodule App.PgRepo do
  use Ecto.Repo,
    otp_app: :dart_messaging_server,
    adapter: Ecto.Adapters.Postgres
end

# defmodule App.MySQLRepo do
#   use Ecto.Repo,
#     otp_app: :dart_messaging_server,
#     adapter: Ecto.Adapters.MyXQL
# end
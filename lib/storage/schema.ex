defmodule Data.DeviceInfo do
  use Ecto.Schema

  @primary_key {:device_id, :string, autogenerate: false}
  schema "devices" do
    field :eid, :string
    field :last_seen, :utc_datetime
    field :status, :string
    field :last_received_version, :integer
    field :ip_address, :string
    field :app_version, :string
    field :os, :string
    field :last_activity, :utc_datetime
    field :supports_notifications, :boolean
    field :supports_media, :boolean
    timestamps(updated_at: false) # optional
  end
end

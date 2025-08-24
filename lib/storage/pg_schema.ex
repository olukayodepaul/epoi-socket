defmodule App.PG.Devices do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}   # SERIAL primary key
  @derive {Jason.Encoder, only: [
    :id, :device_id, :eid, :last_seen, :ws_pid, :status,
    :last_received_version, :ip_address, :app_version,
    :os, :last_activity, :supports_notifications,
    :supports_media, :inserted_at
  ]}
  schema "devices" do
    field :device_id, :string        # unique but not primary key
    field :eid, :string
    field :last_seen, :utc_datetime
    field :ws_pid, :string
    field :status, :string
    field :last_received_version, :integer
    field :ip_address, :string
    field :app_version, :string
    field :os, :string
    field :last_activity, :utc_datetime
    field :supports_notifications, :boolean, default: false
    field :supports_media, :boolean, default: false
    field :inserted_at, :utc_datetime
  end

  # ✅ Changeset function
  def changeset(device, attrs) do
    device
    |> cast(attrs, [
      :device_id, :eid, :last_seen, :ws_pid, :status,
      :last_received_version, :ip_address, :app_version,
      :os, :last_activity, :supports_notifications,
      :supports_media, :inserted_at
    ])
    |> validate_required([:device_id, :eid])
    |> unique_constraint(:device_id)  # enforce uniqueness at DB level
  end
end


defmodule App.PG.Subscriber do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}   # BIGSERIAL primary key
  @derive {Jason.Encoder, only: [
    :id, :owner_eid, :subscriber_eid, :status, :inserted_at
  ]}
  schema "subscriber" do
    field :owner_eid, :string
    field :subscriber_eid, :string
    field :status, :string
    field :inserted_at, :naive_datetime
    field :awareness_status, :string
  end

  # ✅ Changeset function
  def changeset(subscriber, attrs) do
    subscriber
    |> cast(attrs, [:owner_eid, :subscriber_eid, :status, :inserted_at, :awareness_status])
    |> validate_required([:owner_eid, :subscriber_eid, :status])
    |> validate_inclusion(:status, ["ONLINE", "BUSY", "DO_NOT_DISTURB", "OFFLINE"])
    |> unique_constraint([:owner_eid, :subscriber_eid], name: :subscriber_owner_eid_subscriber_eid_index)
  end
end


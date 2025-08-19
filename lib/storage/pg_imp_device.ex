defmodule App.Storage.Postgres.Device do
  @behaviour App.StorageIntf
  alias App.PG.Devices
  alias App.PgRepo, as: Repo

  import Ecto.Query

  # save with upsert on device_id
  def save(%Devices{} = device) do
    device
    |> Device.changeset(%{})   # wrap in changeset (you can adjust attrs if needed)
    |> Repo.insert(
        on_conflict: {:replace_all_except, [:id]}, # keep :id
        conflict_target: :device_id
      )
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # get by device_id (NOT primary key)
  def get(device_id) do
    Repo.get_by(Devices, device_id: device_id)
  end

  def delete(device_id) do
    case Repo.get_by(Devices, device_id: device_id) do
      nil -> {:error, :not_found}
      device -> 
        case Repo.delete(device) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def all_by_user(eid) do
    Devices
    |> where([d], d.eid == ^eid)
    |> Repo.all()
  end

end
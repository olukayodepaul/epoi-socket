defmodule Storage.PgDeviceImp do

  @behaviour Storage.AppStorageIntf
  alias Storage.PgDevicesSchema
  alias App.PgRepo, as: Repo

  import Ecto.Query

  # save with upsert on device_id
  def save(%PgDevicesSchema{} = device) do
    device
    |> PgDevicesSchema.changeset(%{})  # use the correct module
    |> Repo.insert(
        on_conflict: {:replace_all_except, [:id]},  # keep :id
        conflict_target: :device_id
      )
    |> case do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
  end


  # get by device_id (NOT primary key)
  def get(device_id) do
    Repo.get_by(PgDevicesSchema, device_id: device_id)
  end

  def delete(device_id) do
    case Repo.get_by(PgDevicesSchema, device_id: device_id) do
      nil -> {:error, :not_found}
      device -> 
        case Repo.delete(device) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def all_by_user(eid) do
    PgDevicesSchema
    |> where([d], d.eid == ^eid)
    |> Repo.all()
  end

  

end
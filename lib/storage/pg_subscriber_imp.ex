defmodule Storage.PgSubscriberImp do
  
  @behaviour Storage.AppStorageIntf
  alias Storage.PgSubscriberSchema
  alias App.PgRepo, as: Repo

  import Ecto.Query

  # save with upsert on owner_eid + subscriber_eid
  def save(%PgSubscriberSchema{} = subscriber) do
    subscriber
    |> PgSubscriberSchema.changeset(%{})
    |> Repo.insert(
        on_conflict: {:replace_all_except, [:id]},
        conflict_target: [:owner_eid, :subscriber_eid]
      )
    |> case do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
  end

  # get by subscriber_eid
  def get(subscriber_eid) do
    Repo.get_by(PgSubscriberSchema, subscriber_eid: subscriber_eid)
  end

  # delete by subscriber_eid
  def delete(subscriber_eid) do
    case Repo.get_by(PgSubscriberSchema, subscriber_eid: subscriber_eid) do
      nil -> {:error, :not_found}
      subscriber -> 
        case Repo.delete(subscriber) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  # get all subscribers for a given owner
  def all_by_user(owner_eid) do
    PgSubscriberSchema
    |> where([s], s.owner_eid == ^owner_eid)
    |> Repo.all()
  end
end

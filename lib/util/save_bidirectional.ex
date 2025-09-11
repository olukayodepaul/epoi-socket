defmodule Util.SaveBidirectional do
  @moduledoc """
  Save bidirectional subscriptions in DB and update ETS cache.
  """

  alias Storage.{PgSubscriberSchema, GlobalSubscriberCache}
  alias App.PgRepo
  alias Ecto.Multi

  @doc """
  Save bidirectional subscriptions in a single transaction.
  Also updates the ETS cache in `Storage.GlobalSubscriberCache`.
  """
  def save_bidirectional_subscription(from_eid, to_eid) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    # Prepare changesets for DB inserts
    changesets = [
      {:from_to,
      %PgSubscriberSchema{}
      |> PgSubscriberSchema.changeset(%{
        owner_eid: from_eid,
        subscriber_eid: to_eid,
        status: "active",
        awareness_status: "allow",
        inserted_at: now
      })},
      {:to_from,
      %PgSubscriberSchema{}
      |> PgSubscriberSchema.changeset(%{
        owner_eid: to_eid,
        subscriber_eid: from_eid,
        status: "active",
        awareness_status: "allow",
        inserted_at: now
      })}
    ]

    # Build Ecto.Multi for transactional DB insert
    multi =
      Enum.reduce(changesets, Multi.new(), fn {name, changeset}, m ->
        Multi.insert(m, name, changeset,
          on_conflict: {:replace_all_except, [:id]},
          conflict_target: [:owner_eid, :subscriber_eid]
        )
      end)

    case PgRepo.transaction(multi) do
      {:ok, _results} ->
        # Update ETS cache for both directions
        Enum.each(changesets, fn {_name, changeset} ->
          GlobalSubscriberCache.save(Ecto.Changeset.apply_changes(changeset))
        end)

        :ok

      {:error, failed_op, reason, _changes} ->
        {:error, {failed_op, reason}}
    end
  end
end

defmodule App.Storage do
  @moduledoc """
  Unified storage module. Delegates to the configured backend
  based on the selected DB in the configuration.
  """

  # Returns the backend module dynamically
  defp backend do
    case ApplicationServer.Configuration.selected_db() do
      :postgres -> App.Storage.Postgres
      # :mysql -> App.Storage.MySQL
      # :mongo -> App.Storage.Mongo
      # :redis -> App.Storage.Redis  # if you implement Redis storage
      other -> raise "Unsupported storage backend: #{inspect(other)}"
    end
  end

  # Delegated functions
  def save(device), do: backend().save(device)
  def get(device_id), do: backend().get(device_id)
  def delete(device_id), do: backend().delete(device_id)
  def all_by_user(eid), do: backend().all_by_user(eid)
end

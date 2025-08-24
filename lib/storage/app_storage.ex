defmodule App.Storage.Delegator do
  @moduledoc """
  Unified storage module. Delegates to the configured backend
  based on the selected DB in the configuration.
  """

  # Returns the backend module for devices
  defp device_backend do
    case ApplicationServer.Configuration.selected_db() do
      :postgres -> App.Storage.Postgres.Device
      # :mysql -> App.Storage.MySQL.Device
      # :mongo -> App.Storage.Mongo.Device
      other -> raise "Unsupported storage backend: #{inspect(other)}"
    end
  end

  # Returns the backend module for subscribers
  defp subscriber_backend do
    case ApplicationServer.Configuration.selected_db() do
      :postgres -> App.Storage.Postgres.Subscriber
      # :mysql -> App.Storage.MySQL.Subscriber
      # :mongo -> App.Storage.Mongo.Subscriber
      other -> raise "Unsupported storage backend: #{inspect(other)}"
    end
  end

  # Device delegated functions
  def save_device(device), do: device_backend().save(device)
  def get_device(device_id), do: device_backend().get(device_id)
  def delete_device(device_id), do: device_backend().delete(device_id)
  def all_devices_by_user(eid), do: device_backend().all_by_user(eid)

  # Subscriber delegated functions
  def save_subscriber(subscriber), do: subscriber_backend().save(subscriber)
  def get_subscriber(subscriber_eid), do: subscriber_backend().get(subscriber_eid)
  def delete_subscriber(subscriber_eid), do: subscriber_backend().delete(subscriber_eid)
  def all_subscribers_by_user(owner_eid), do: subscriber_backend().all_by_user(owner_eid)
end


#App.Storage.Delegator.all_subscribers_by_user("a@domain.com")
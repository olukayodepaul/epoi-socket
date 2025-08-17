defmodule App.StorageIntf do
  @moduledoc """
  Defines the contract any database backend must implement
  to be usable by the system.
  """

  @callback save(struct()) :: :ok | {:error, term()}
  @callback get(device_id :: String.t()) :: struct() | nil
  @callback delete(device_id :: String.t()) :: :ok | {:error, term()}
  @callback all_by_user(eid :: String.t()) :: [struct()]
end
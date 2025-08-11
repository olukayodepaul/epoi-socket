defmodule Util.TokenRevoked do
  require Logger

  @table :token_revocation

  def ensure_tables do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
        Logger.debug("Created ETS table #{@table}")
      _ -> :ok
    end
  end

  def store_revocation(device_id, jti, exp) do
    value = %{jti: jti, exp: exp}
    :ets.insert(@table, {device_id, value})
    Redix.command!(:redix, ["HSET", "token_revocation", device_id, Jason.encode!(value)])
    :ok
  end

  @doc """
  Returns true if device_id is revoked, otherwise false.
  """
  def revoked?(device_id) do
    case :ets.lookup(@table, device_id) do
      [{^device_id, _}] ->
        true

      [] ->
        case Redix.command!(:redix, ["HEXISTS", "token_revocation", device_id]) do
          1 ->
            # optional: sync from Redis to ETS
            case Redix.command!(:redix, ["HGET", "token_revocation", device_id]) do
              nil -> false
              json ->
                data = Jason.decode!(json)
                :ets.insert(@table, {device_id, data})
                true
            end

          0 -> false
        end
    end
  end
end

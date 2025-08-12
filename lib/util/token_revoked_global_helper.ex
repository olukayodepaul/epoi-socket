defmodule Util.TokenRevoked do
  require Logger

  def store_revocation(jti, exp) do
    ttl = exp - System.os_time(:second)

    if ttl > 0 do
      value = %{jti: jti, exp: exp}

      # Save in Redis with TTL
      Redix.pipeline!(:redix, [
        ["SETEX", "revoked:#{jti}", ttl, Jason.encode!(value)]
      ])
    end

    :ok
  end

  def revoked?(jti) do
    case Redix.command!(:redix, ["HEXISTS", "token_revocation", jti]) do
      1 -> true
      0 -> false
    end
  end

end

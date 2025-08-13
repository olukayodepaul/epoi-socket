defmodule Security.TokenVerifier do
  use Joken.Config
  require Logger

  @public_key_path "priv/keys/public.pem"

  def base_claims do
    default_claims(skip: [:aud])
    |> add_claim("device_id", nil, &is_binary/1)
    |> add_claim("eid", nil, &is_binary/1)
    |> add_claim("jti", fn -> System.unique_integer([:positive]) |> Integer.to_string() end, &is_binary/1)
    |> add_claim("type", nil, &(&1 in ["access", "refresh"]))
  end


  defp load_public_key do
    File.read!(@public_key_path)
    |> JOSE.JWK.from_pem()
    |> JOSE.JWK.to_map()
    |> elem(1)
  end

  def verifier do
    Joken.Signer.create("RS256", load_public_key())
  end

  def extract_token(nil) do
    Logger.warning("Attempted to extract token from nil")
    {:error, :invalid_token}
  end

  def extract_token("") do
    Logger.warning("Attempted to extract token from empty string")
    {:error, :invalid_token}
  end

  def extract_token("Bearer " <> token) when is_binary(token), do: {:ok, token}
  def extract_token(token) when is_binary(token), do: {:ok, token}

  def verify_from_header(header) do
    case extract_token(header) do
      {:ok, token} -> verify_token(token)
      _ ->
        Logger.warning("Invalid authorization header: #{inspect(header)}")
        {:error, :invalid_header}
    end
  end

  def verify_token(token) do
    case verify_and_validate(token, verifier()) do
      {:ok, claims} ->
        if token_revoked?(claims["jti"]) do
          Logger.warning("Token revoked: jti=#{claims["jti"]}")
          {:error, :invalid_token}
        else
          Logger.info("Token verified successfully: jti=#{claims["jti"]}")
          {:ok, claims}
        end

      {:error, reason} ->
        Logger.warning("Token verification failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def token_revoked?(_jti), do: false

  def extract_jti(token) do
    try do
      case Joken.peek_claims(token) do
        {:ok, %{"jti" => jti}} when is_binary(jti) -> {:ok, jti}
        _ ->
          Logger.warning("JTI missing or invalid in token")
          {:error, :invalid_token}
      end
    rescue
      _ ->
        Logger.error("Failed to extract JTI from token (exception)")
        {:error, :invalid_token}
    end
  end

  def check_token_expiration(token) do
    try do
      case Joken.peek_claims(token) do
        {:ok, %{"exp" => exp}} when is_integer(exp) ->
          now = DateTime.utc_now() |> DateTime.to_unix()
          if exp > now do
            {:ok, :valid}
          else
            Logger.warning("Token expired at #{exp}, current time #{now}")
            {:error, :token_expired}
          end

        _ ->
          Logger.warning("Expiration claim missing or invalid in token")
          {:error, :invalid_token}
      end
    rescue
      _ ->
        Logger.error("Failed to check token expiration (exception)")
        {:error, :invalid_token}
    end
  end
end



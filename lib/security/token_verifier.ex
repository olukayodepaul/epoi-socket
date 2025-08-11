defmodule Security.DeviceVerifier do
  @moduledoc """
  JWT verification for device tokens using a public key.
  """

  use Joken.Config

  @public_key_path "priv/keys/public.pem"

  # Configure base claims
  @impl true
  def token_config do
    default_claims(skip: [:aud])
    |> add_claim("device_id", nil, &is_binary/1)
    |> add_claim("eid", nil, &is_binary/1)
    |> add_claim("jti", nil, &is_binary/1)
    |> add_claim("type", nil, &(&1 in ["access", "refresh"]))
  end

  # Load the public key for RS256 verification
  defp load_public_key do
    File.read!(@public_key_path)
    |> JOSE.JWK.from_pem()
  end

  def verifier do
    Joken.Signer.create("RS256", load_public_key())
  end

  # Extract token from Authorization header or direct string
  def extract_token("Bearer " <> token), do: {:ok, token}
  def extract_token(token) when is_binary(token) and token != "", do: {:ok, token}
  def extract_token(_), do: {:error, :invalid_token}

  # Verify token from Authorization header
  def verify_from_header(header) do
    with {:ok, token} <- extract_token(header), {:ok, claims} <- verify_token(token) do
      {:ok, claims}
    else
      _ -> {:error, :invalid_token}
    end
  end

  # Verify and validate token
  def verify_token(token) do
    case verify_and_validate(token, verifier()) do
      {:ok, claims} -> {:ok, claims}
      {:error, _} -> {:error, :invalid_token}
    end
  end

  # Extract specific claims without validation
  def extract_jti(token), do: extract_claim(token, "jti")
  def extract_device_id(token), do: extract_claim(token, "device_id")

  defp extract_claim(token, claim) do
    try do
      case Joken.peek_claims(token) do
        {:ok, %{^claim => value}} when is_binary(value) -> {:ok, value}
        _ -> {:error, :invalid_token}
      end
    rescue
      _ -> {:error, :invalid_token}
    end
  end

  # Check if token is expired
  def check_token_expiration(token) do
    try do
      case Joken.peek_claims(token) do
        {:ok, %{"exp" => exp}} when is_integer(exp) ->
          now = DateTime.utc_now() |> DateTime.to_unix()
          if exp > now, do: {:ok, :valid}, else: {:error, :token_expired}

        _ -> {:error, :invalid_token}
      end
    rescue
      _ -> {:error, :invalid_token}
    end
  end
end

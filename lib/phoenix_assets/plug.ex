defmodule PhoenixAssets.Plug do
  @moduledoc """
  A development plug exposing asset-runtime status at `GET /__assets/status`.

  Mounted in the endpoint during development, it returns a small JSON document
  describing whether dev mode is active and whether the production manifest is
  loaded -- handy for the dev overlay, Tidewave, and quick `curl` checks. In
  production (or whenever `:enabled` is false) it passes the connection through
  untouched.

  ## Usage

      plug PhoenixAssets.Plug

  ## Why

  A single, predictable status endpoint means tooling does not have to reach into
  internals to learn the asset pipeline's state.
  """

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: Keyword.put_new_lazy(opts, :enabled, &PhoenixAssets.dev?/0)

  @impl Plug
  def call(%Plug.Conn{path_info: ["__assets", "status"]} = conn, opts) do
    if Keyword.get(opts, :enabled, false) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(status()))
      |> halt()
    else
      conn
    end
  end

  def call(conn, _), do: conn

  defp status do
    %{
      dev: PhoenixAssets.dev?(),
      manifest: manifest_status(),
      version: PhoenixAssets.version()
    }
  end

  defp manifest_status do
    case PhoenixAssets.ManifestServer.manifest() do
      :dev -> "dev"
      {:error, _} -> "missing"
      manifest when is_map(manifest) -> "loaded"
    end
  end
end

defmodule PhoenixAssets.PlugManifestStatusTest do
  @moduledoc """
  Manifest-status branches of the dev status plug. Separate from PlugTest because
  these toggle the global dev flag and the ManifestServer cache, so they must run
  non-async.
  """

  use ExUnit.Case, async: false

  import Plug.Test

  alias PhoenixAssets.ManifestServer
  alias PhoenixAssets.Plug, as: AssetsPlug

  setup do
    :persistent_term.erase({ManifestServer, :manifest})
    on_exit(fn -> :persistent_term.erase({ManifestServer, :manifest}) end)
    :ok
  end

  defp manifest_status(opts) do
    conn = :get |> conn("/__assets/status") |> AssetsPlug.call(AssetsPlug.init(opts))
    JSON.decode!(conn.resp_body)["manifest"]
  end

  test ~s|reports "loaded" when a manifest map is cached| do
    :persistent_term.put({ManifestServer, :manifest}, %{"src/app.ts" => %{"file" => "x"}})

    assert manifest_status(enabled: true) == "loaded"
  end

  test ~s|reports "dev" in development| do
    Application.put_env(:phoenix_assets, :dev, enabled: true)
    on_exit(fn -> Application.delete_env(:phoenix_assets, :dev) end)

    assert manifest_status(enabled: true) == "dev"
  end
end

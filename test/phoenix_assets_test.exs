defmodule PhoenixAssetsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias PhoenixAssets.{Config, ManifestServer}

  setup do
    saved = Application.get_all_env(:phoenix_assets)

    on_exit(fn ->
      for {key, _} <- Application.get_all_env(:phoenix_assets) do
        Application.delete_env(:phoenix_assets, key)
      end

      for {key, value} <- saved, do: Application.put_env(:phoenix_assets, key, value)
    end)

    Application.put_env(:phoenix_assets, :otp_app, :phoenix_assets)
    :ok
  end

  test "children/0 is empty; the host adds child_specs/1 instead" do
    assert PhoenixAssets.children() == []
  end

  test "version/0 returns the installed semantic version" do
    assert PhoenixAssets.version() =~ ~r/^\d+\.\d+\.\d+/
  end

  test "dev?/0 reflects the :dev enabled flag" do
    refute PhoenixAssets.dev?()
    Application.put_env(:phoenix_assets, :dev, enabled: true)
    assert PhoenixAssets.dev?()
  end

  test "vite_dev_url/1 builds a URL from the configured host/port, with defaults" do
    assert PhoenixAssets.vite_dev_url("x.js") == "http://127.0.0.1:5173/x.js"
    Application.put_env(:phoenix_assets, :dev, vite: [host: "0.0.0.0", port: 4000])
    assert PhoenixAssets.vite_dev_url("/app.js") == "http://0.0.0.0:4000/app.js"
  end

  test "asset_path/1 falls back to a root-relative path in dev" do
    Application.put_env(:phoenix_assets, :dev, enabled: true)
    assert PhoenixAssets.asset_path("app.js") == "/app.js"
    assert PhoenixAssets.asset_path("/app.js") == "/app.js"
  end

  test "entry!/1 returns :dev when the manifest server is in dev mode" do
    Application.put_env(:phoenix_assets, :dev, enabled: true)
    assert PhoenixAssets.entry!("app") == :dev
  end

  test "entry!/1 raises when a production manifest is expected but missing" do
    :persistent_term.put({ManifestServer, :manifest}, {:error, :missing})
    on_exit(fn -> :persistent_term.erase({ManifestServer, :manifest}) end)

    assert_raise RuntimeError, ~r/manifest unavailable/, fn -> PhoenixAssets.entry!("app") end
  end

  test "child_specs/1 includes the manifest server, adding the dev supervisor in dev" do
    config = Config.load!(otp_app: :phoenix_assets)
    assert [{ManifestServer, _}] = PhoenixAssets.child_specs(config: config)

    Application.put_env(:phoenix_assets, :dev, enabled: true)
    assert length(PhoenixAssets.child_specs(config: config)) == 2
  end

  test "graph/0 is an empty map when no graph.json has been built" do
    assert PhoenixAssets.graph() == %{}
  end

  test "page!/1 and route!/1 raise KeyError when the graph lacks the key" do
    assert_raise KeyError, fn -> PhoenixAssets.page!("Nope") end
    assert_raise KeyError, fn -> PhoenixAssets.route!("nope") end
  end
end

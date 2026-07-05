defmodule PhoenixAssetsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias PhoenixAssets.{Config, Context, Graph, ManifestServer}

  defmodule GraphPagePlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def graph_entries(_, _) do
      [Graph.Entry.new(kind: :page, key: "Home", data: %{"route" => "/"})]
    end
  end

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

  test "vite_dev_url/1 prefers the hot file the Vite plugin writes" do
    root = Path.join(System.tmp_dir!(), "hot_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, ".phoenix-assets"))
    File.write!(Path.join(root, ".phoenix-assets/hot"), "https://localhost:5174/\n")
    on_exit(fn -> File.rm_rf!(root) end)

    Application.put_env(:phoenix_assets, :asset_root, root)
    assert PhoenixAssets.vite_dev_url("app.js") == "https://localhost:5174/app.js"

    # Garbage in the hot file falls back to the configured URL.
    File.write!(Path.join(root, ".phoenix-assets/hot"), "not a url")
    assert PhoenixAssets.vite_dev_url("app.js") == "http://127.0.0.1:5173/app.js"
  end

  test "entry!/1 and asset_path/1 apply the configured :asset_url prefix" do
    :persistent_term.put(
      {ManifestServer, :manifest},
      %{
        "src/app.ts" => %{
          "file" => "assets/app-AAA.js",
          "isEntry" => true,
          "css" => ["assets/app.css"],
          "imports" => [],
          "integrity" => "sha384-APP"
        }
      }
    )

    on_exit(fn -> :persistent_term.erase({ManifestServer, :manifest}) end)
    Application.put_env(:phoenix_assets, :build, asset_url: "https://cdn.example.com/")

    resolved = PhoenixAssets.entry!("src/app.ts")
    assert resolved.file == "https://cdn.example.com/assets/app-AAA.js"
    assert resolved.css == ["https://cdn.example.com/assets/app.css"]
    assert resolved.integrity == %{"https://cdn.example.com/assets/app-AAA.js" => "sha384-APP"}

    assert PhoenixAssets.asset_path("src/app.ts") == "https://cdn.example.com/assets/app-AAA.js"
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

  test "child_specs starts the manifest server with the resolved default path, not nil" do
    # Regression: a prod-config app must serve assets, so the ManifestServer
    # child has to carry the DEFAULT resolved manifest path (Context.manifest_path)
    # rather than `nil` (which would make every manifest read resolve to :missing).
    config = Config.load!(otp_app: :phoenix_assets)

    assert [{ManifestServer, opts}] = PhoenixAssets.child_specs(config: config)

    refute is_nil(opts[:path])
    assert opts[:path] == Context.manifest_path(Context.new(config))
    assert opts[:path] == "priv/static/assets/.vite/manifest.json"
  end

  test "child_specs honours a :vite_manifest build override for the manifest path" do
    config =
      Config.load!(otp_app: :phoenix_assets, build: [vite_manifest: "custom/manifest.json"])

    assert [{ManifestServer, opts}] = PhoenixAssets.child_specs(config: config)
    assert opts[:path] == "custom/manifest.json"
  end

  test "graph/0 is an empty map when no graph.json has been built" do
    assert PhoenixAssets.graph() == %{}
  end

  test "page!/1 and route!/1 raise KeyError when the graph lacks the key" do
    assert_raise KeyError, fn -> PhoenixAssets.page!("Nope") end
    assert_raise KeyError, fn -> PhoenixAssets.route!("nope") end
  end

  test "graph/0 loads a built graph.json and page!/1 returns the found entry" do
    tmp = Path.join(System.tmp_dir!(), "pg_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)
    graph_path = Path.join(tmp, "graph.json")
    Application.put_env(:phoenix_assets, :build, asset_graph: graph_path)

    ctx =
      Context.new(Config.load!(otp_app: :phoenix_assets, build: [asset_graph: graph_path]),
        env: :test,
        plugins: [{GraphPagePlugin, []}]
      )

    assert {:ok, _} = Graph.write(ctx)

    assert PhoenixAssets.graph()["pages"]["Home"] == %{"route" => "/"}
    assert PhoenixAssets.page!("Home") == %{"route" => "/"}
  end
end

defmodule PhoenixAssets.ComponentsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias PhoenixAssets.{Components, ManifestServer}

  @manifest %{
    "src/app.ts" => %{
      "file" => "assets/app-AAA.js",
      "css" => ["assets/app-CSS.css"],
      "imports" => []
    }
  }

  setup do
    path = Path.join(System.tmp_dir!(), "c_#{System.unique_integer([:positive])}.json")
    File.write!(path, JSON.encode!(@manifest))
    on_exit(fn -> File.rm_rf!(path) end)
    start_supervised!({ManifestServer, path: path})
    :ok
  end

  test "vite_assets renders manifest-resolved script and stylesheet in production" do
    html = render_component(&Components.vite_assets/1, entry: "src/app.ts")

    assert html =~ ~s(src="/assets/app-AAA.js")
    assert html =~ ~s(rel="stylesheet")
    assert html =~ "/assets/app-CSS.css"
  end

  test "svelte_page renders a mount point with serialized props" do
    html = render_component(&Components.svelte_page/1, name: "Dashboard", props: %{count: 3})

    assert html =~ ~s(data-svelte-page="Dashboard")
    assert html =~ "count"
  end

  test "svelte_page derives a `svelte-<name>` id when none is given" do
    html = render_component(&Components.svelte_page/1, name: "Dashboard")

    assert html =~ ~s(id="svelte-Dashboard")
    assert html =~ ~s(data-svelte-page="Dashboard")
  end

  test "svelte_page honours an explicit :id over the generated one" do
    html = render_component(&Components.svelte_page/1, name: "Dashboard", id: "app-root")

    assert html =~ ~s(id="app-root")
    refute html =~ ~s(id="svelte-Dashboard")
  end

  test "vite_assets emits modulepreload links, with SRI when the manifest carries it" do
    manifest = %{
      "src/app.ts" => %{
        "file" => "assets/app-AAA.js",
        "integrity" => "sha384-APP",
        "css" => [],
        "imports" => ["_vendor-BBB.js"]
      },
      "_vendor-BBB.js" => %{"file" => "assets/vendor-BBB.js", "integrity" => "sha384-VENDOR"}
    }

    :persistent_term.put({ManifestServer, :manifest}, manifest)
    on_exit(fn -> :persistent_term.erase({ManifestServer, :manifest}) end)

    html = render_component(&Components.vite_assets/1, entry: "src/app.ts")

    assert html =~ ~s(rel="modulepreload")
    assert html =~ ~s(href="/assets/vendor-BBB.js")
    assert html =~ ~s(integrity="sha384-VENDOR")
    assert html =~ ~s(integrity="sha384-APP")
    assert html =~ ~s(crossorigin="anonymous")
  end

  test "vite_assets points at the dev server and HMR client in development" do
    Application.put_env(:phoenix_assets, :dev, enabled: true)
    on_exit(fn -> Application.delete_env(:phoenix_assets, :dev) end)

    html = render_component(&Components.vite_assets/1, entry: "src/app.ts")

    assert html =~ ~s(src="http://127.0.0.1:5173/@vite/client")
    assert html =~ ~s(src="http://127.0.0.1:5173/src/app.ts")
    assert html =~ ~s(type="module")
    refute html =~ "/assets/app-AAA.js"
  end

  test "production tags carry phx-track-static and the nonce reaches preloads" do
    manifest = %{
      "src/app.ts" => %{
        "file" => "assets/app-AAA.js",
        "css" => ["assets/app-CSS.css"],
        "imports" => ["_vendor-BBB.js"]
      },
      "_vendor-BBB.js" => %{"file" => "assets/vendor-BBB.js"}
    }

    :persistent_term.put({ManifestServer, :manifest}, manifest)
    on_exit(fn -> :persistent_term.erase({ManifestServer, :manifest}) end)

    html = render_component(&Components.vite_assets/1, entry: "src/app.ts", nonce: "n0nce")

    assert html =~ "phx-track-static"

    preload_line =
      html |> String.split("\n") |> Enum.find(&String.contains?(&1, "modulepreload"))

    assert preload_line =~ ~s(nonce="n0nce")
  end

  test "speculation_rules emits a prefetch block from the given routes" do
    html =
      render_component(&Components.speculation_rules/1,
        routes: ["/", "/users/:id"],
        nonce: "n0nce"
      )

    assert html =~ ~s(type="speculationrules")
    assert html =~ ~s(nonce="n0nce")
    assert html =~ ~s("href_matches":"/users/:id")
    assert html =~ ~s("eagerness":"moderate")
  end

  test "speculation_rules renders nothing without routes" do
    assert render_component(&Components.speculation_rules/1, routes: []) |> String.trim() == ""
  end
end

defmodule PhoenixAssets.EarlyHintsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  import Plug.Test

  alias PhoenixAssets.{EarlyHints, ManifestServer}

  @manifest %{
    "src/app.ts" => %{
      "file" => "assets/app-AAA.js",
      "css" => ["assets/app-CSS.css"],
      "imports" => ["_vendor-BBB.js"]
    },
    "_vendor-BBB.js" => %{"file" => "assets/vendor-BBB.js"}
  }

  setup do
    :persistent_term.erase({ManifestServer, :manifest})
    on_exit(fn -> :persistent_term.erase({ManifestServer, :manifest}) end)
    :ok
  end

  defp call(opts) do
    conn = conn(:get, "/")
    EarlyHints.call(conn, EarlyHints.init(opts))
  end

  test "sends 103 hints for the entry's stylesheets and module chunks" do
    :persistent_term.put({ManifestServer, :manifest}, @manifest)

    conn = call(entry: "src/app.ts")

    assert [{103, headers}] = Plug.Test.sent_informs(conn)

    links = for {"link", value} <- headers, do: value
    assert "</assets/app-CSS.css>; rel=preload; as=style" in links
    assert "</assets/app-AAA.js>; rel=modulepreload" in links
    assert "</assets/vendor-BBB.js>; rel=modulepreload" in links
  end

  test "passes through when no manifest is loaded" do
    conn = call(entry: "src/app.ts")
    assert Plug.Test.sent_informs(conn) == []
  end

  test "passes through in dev mode" do
    Application.put_env(:phoenix_assets, :dev, enabled: true)
    on_exit(fn -> Application.delete_env(:phoenix_assets, :dev) end)

    conn = call(entry: "src/app.ts")
    assert Plug.Test.sent_informs(conn) == []
  end

  test "an unknown entry passes through rather than crashing the request" do
    :persistent_term.put({ManifestServer, :manifest}, @manifest)

    conn = call(entry: "src/ghost.ts")
    assert Plug.Test.sent_informs(conn) == []
  end

  test "init/1 requires an :entry" do
    assert_raise KeyError, fn -> EarlyHints.init([]) end
  end
end

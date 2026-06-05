defmodule PhoenixAssets.ManifestTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.Manifest

  @manifest %{
    "src/app.ts" => %{
      "file" => "assets/app-AAA.js",
      "isEntry" => true,
      "css" => ["assets/app-CSS.css"],
      "imports" => ["_vendor-BBB.js"]
    },
    "_vendor-BBB.js" => %{
      "file" => "assets/vendor-BBB.js",
      "css" => ["assets/vendor-CSS.css"],
      "imports" => ["_shared-CCC.js"]
    },
    "_shared-CCC.js" => %{"file" => "assets/shared-CCC.js"}
  }

  test "file/2 returns the prefixed hashed file" do
    assert Manifest.file(@manifest, "src/app.ts") == "/assets/app-AAA.js"
  end

  test "css/2 collects entry and transitive import stylesheets in order" do
    assert Manifest.css(@manifest, "src/app.ts") ==
             ["/assets/app-CSS.css", "/assets/vendor-CSS.css"]
  end

  test "imports/2 returns transitive chunk files, excluding the entry's own" do
    assert Manifest.imports(@manifest, "src/app.ts") ==
             ["/assets/vendor-BBB.js", "/assets/shared-CCC.js"]
  end

  test "preload_links/2 mirrors imports/2" do
    assert Manifest.preload_links(@manifest, "src/app.ts") ==
             Manifest.imports(@manifest, "src/app.ts")
  end

  test "subresource_integrity/2 is empty when no chunk declares a hash" do
    assert Manifest.subresource_integrity(@manifest, "src/app.ts") == %{}
  end

  test "subresource_integrity/2 maps hrefs to hashes across transitive imports" do
    manifest = %{
      "src/app.ts" => %{
        "file" => "assets/app-AAA.js",
        "integrity" => "sha384-APP",
        "imports" => ["_vendor-BBB.js"]
      },
      "_vendor-BBB.js" => %{"file" => "assets/vendor-BBB.js", "integrity" => "sha384-VENDOR"}
    }

    assert Manifest.subresource_integrity(manifest, "src/app.ts") == %{
             "/assets/app-AAA.js" => "sha384-APP",
             "/assets/vendor-BBB.js" => "sha384-VENDOR"
           }
  end

  test "entry!/2 raises for an unknown key" do
    assert_raise KeyError, fn -> Manifest.entry!(@manifest, "nope") end
  end

  test "load/1 decodes a manifest file" do
    path = Path.join(System.tmp_dir!(), "m_#{System.unique_integer([:positive])}.json")
    File.write!(path, Jason.encode!(@manifest))
    on_exit(fn -> File.rm_rf!(path) end)

    assert {:ok, loaded} = Manifest.load(path)
    assert Manifest.file(loaded, "src/app.ts") == "/assets/app-AAA.js"
  end

  test "load/1 errors for a missing file" do
    assert {:error, _} = Manifest.load("/nonexistent/manifest.json")
  end
end

defmodule PhoenixAssets.ManifestServerTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias PhoenixAssets.{Manifest, ManifestServer}

  @manifest %{"src/app.ts" => %{"file" => "assets/app-AAA.js", "css" => [], "imports" => []}}

  defp start_with_manifest do
    path = Path.join(System.tmp_dir!(), "ms_#{System.unique_integer([:positive])}.json")
    File.write!(path, Jason.encode!(@manifest))
    on_exit(fn -> File.rm_rf!(path) end)
    start_supervised!({ManifestServer, path: path})
  end

  test "serves a loaded manifest" do
    start_with_manifest()
    assert Manifest.file(ManifestServer.manifest(), "src/app.ts") == "/assets/app-AAA.js"
  end

  test "reports missing when no path is configured" do
    start_supervised!({ManifestServer, []})
    assert ManifestServer.manifest() == {:error, :missing}
  end

  test "facade entry!/1 resolves from the loaded manifest" do
    start_with_manifest()

    assert PhoenixAssets.entry!("src/app.ts") == %{
             file: "/assets/app-AAA.js",
             css: [],
             imports: [],
             integrity: %{}
           }
  end

  test "facade asset_path/1 returns the hashed path" do
    start_with_manifest()
    assert PhoenixAssets.asset_path("src/app.ts") == "/assets/app-AAA.js"
  end

  test "reload/1 refreshes from disk" do
    start_with_manifest()
    assert :ok = ManifestServer.reload()
  end

  test "reload/0 keeps the last-good manifest when the file becomes unreadable" do
    path = Path.join(System.tmp_dir!(), "ms_#{System.unique_integer([:positive])}.json")
    File.write!(path, Jason.encode!(@manifest))
    on_exit(fn -> File.rm_rf!(path) end)
    start_supervised!({ManifestServer, path: path})

    assert Manifest.file(ManifestServer.manifest(), "src/app.ts") == "/assets/app-AAA.js"

    # A mid-deploy transient failure: the manifest is momentarily unreadable.
    File.rm!(path)
    assert :ok = ManifestServer.reload()

    # The cache must still serve the last-good manifest, not {:error, :missing}.
    assert Manifest.file(ManifestServer.manifest(), "src/app.ts") == "/assets/app-AAA.js"
  end
end

defmodule Mix.Tasks.PhoenixAssets.GenTest do
  @moduledoc false

  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  defmodule Shapes do
    @moduledoc false
    use PhoenixAssets.Electric.Shapes

    shape(:portfolios, route: "/shapes/portfolios", type: "PortfolioRow")
  end

  defmodule Types do
    @moduledoc false
    use PhoenixAssets.Types.Schema

    type("PortfolioRow", resource: PhoenixAssets.TestSupport.Portfolio, only: :public)
  end

  setup do
    root = Path.join(System.tmp_dir!(), "pa_task_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "src"))
    File.mkdir_p!(Path.join(root, "node_modules/.bin"))
    File.write!(Path.join(root, "svelte.config.js"), "export default {}\n")
    File.write!(Path.join(root, "package.json"), "{}\n")
    File.write!(Path.join(root, "src/app.css"), "@import \"tailwindcss\";\n")

    saved = Application.get_all_env(:phoenix_assets)

    on_exit(fn ->
      for {key, _} <- Application.get_all_env(:phoenix_assets) do
        Application.delete_env(:phoenix_assets, key)
      end

      for {key, value} <- saved, do: Application.put_env(:phoenix_assets, key, value)
      File.rm_rf!(root)
    end)

    Application.put_env(:phoenix_assets, :otp_app, :phoenix_assets)
    Application.put_env(:phoenix_assets, :asset_root, root)
    Application.put_env(:phoenix_assets, :static_root, Path.join(root, "static"))
    Application.put_env(:phoenix_assets, :build, asset_graph: Path.join(root, "graph.json"))
    Application.put_env(:phoenix_assets, :stack, shapes: Shapes, types: Types)

    %{root: root}
  end

  defp gen(args), do: capture_io(fn -> Mix.Task.rerun("phoenix_assets.gen", args) end)

  test "gen writes the contracts and reports counts", %{root: root} do
    assert gen([]) =~ "written"
    assert File.exists?(Path.join(root, "src/lib/generated/types.ts"))
    assert File.exists?(Path.join(root, "src/lib/generated/electric.ts"))
  end

  test "gen --check raises on drift, then reports up to date once written" do
    assert_raise Mix.Error, fn -> gen(["--check"]) end

    gen([])
    assert gen(["--check"]) =~ "up to date"
  end

  test "gen --only restricts the generated kinds", %{root: root} do
    gen(["--only", "types"])

    assert File.exists?(Path.join(root, "src/lib/generated/types.ts"))
    refute File.exists?(Path.join(root, "src/lib/generated/electric.ts"))
  end

  test "doctor prints a grouped report" do
    out = capture_io(fn -> Mix.Task.rerun("phoenix_assets.doctor", []) end)
    assert out =~ "sveltekit"
  end

  test "clean removes the files this library generated", %{root: root} do
    gen([])
    assert File.exists?(Path.join(root, "src/lib/generated/electric.ts"))

    out = capture_io(fn -> Mix.Task.rerun("phoenix_assets.clean", []) end)

    assert out =~ "removed"
    refute File.exists?(Path.join(root, "src/lib/generated/electric.ts"))
  end

  # Hosts co-locate their own artifacts in this directory, and a directory-wide
  # rm -rf deleted hand-written files that took real work to reconstruct.
  test "clean leaves files it did not generate", %{root: root} do
    gen([])
    theirs = Path.join(root, "src/lib/generated/shapes.ts")
    File.write!(theirs, "export const shapes = {}\n")

    out = capture_io(fn -> Mix.Task.rerun("phoenix_assets.clean", []) end)

    assert File.read!(theirs) == "export const shapes = {}\n"
    refute out =~ "shapes.ts"
  end

  test "clean keeps a generated file that was edited by hand, and says so", %{root: root} do
    gen([])
    edited = Path.join(root, "src/lib/generated/electric.ts")
    File.write!(edited, "// hand-edited\n")

    out = capture_io(fn -> Mix.Task.rerun("phoenix_assets.clean", []) end)

    assert File.read!(edited) == "// hand-edited\n"
    assert out =~ "differ from generated output"
    assert out =~ "electric.ts"
  end

  test "clean --all removes the directory outright", %{root: root} do
    gen([])
    File.write!(Path.join(root, "src/lib/generated/theirs.ts"), "export const x = 1\n")

    out = capture_io(fn -> Mix.Task.rerun("phoenix_assets.clean", ["--all"]) end)

    assert out =~ "removed"
    refute File.dir?(Path.join(root, "src/lib/generated"))
  end

  test "graph writes the asset graph json", %{root: root} do
    out = capture_io(fn -> Mix.Task.rerun("phoenix_assets.graph", []) end)

    assert out =~ "asset graph"
    assert File.exists?(Path.join(root, "graph.json"))
  end
end

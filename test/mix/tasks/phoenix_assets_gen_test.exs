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
    assert File.exists?(Path.join(root, "src/generated/types.ts"))
    assert File.exists?(Path.join(root, "src/generated/electric.ts"))
  end

  test "gen --check raises on drift, then reports up to date once written" do
    assert_raise Mix.Error, fn -> gen(["--check"]) end

    gen([])
    assert gen(["--check"]) =~ "up to date"
  end

  test "gen --only restricts the generated kinds", %{root: root} do
    gen(["--only", "types"])

    assert File.exists?(Path.join(root, "src/generated/types.ts"))
    refute File.exists?(Path.join(root, "src/generated/electric.ts"))
  end

  test "doctor prints a grouped report" do
    out = capture_io(fn -> Mix.Task.rerun("phoenix_assets.doctor", []) end)
    assert out =~ "sveltekit"
  end

  test "clean removes the generated directory", %{root: root} do
    gen([])
    assert File.dir?(Path.join(root, "src/generated"))

    out = capture_io(fn -> Mix.Task.rerun("phoenix_assets.clean", []) end)
    assert out =~ "removed"
    refute File.dir?(Path.join(root, "src/generated"))
  end

  test "graph writes the asset graph json", %{root: root} do
    out = capture_io(fn -> Mix.Task.rerun("phoenix_assets.graph", []) end)

    assert out =~ "asset graph"
    assert File.exists?(Path.join(root, "graph.json"))
  end
end

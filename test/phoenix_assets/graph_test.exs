defmodule PhoenixAssets.GraphTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias PhoenixAssets.{Config, Context, Graph}
  alias PhoenixAssets.Graph.Entry

  defmodule FailPlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def init(_, _), do: {:error, :boom}
  end

  defmodule FakePlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def graph_entries(_, _) do
      [
        Entry.new(
          kind: :page,
          key: "Home",
          data: %{"route" => "/"},
          source: "src/routes/+page.svelte"
        ),
        Entry.new(kind: :route, key: "health", data: %{"path" => "/api/health"}),
        Entry.new(kind: :electric_shape, key: "portfolios", data: %{"table" => "portfolios"})
      ]
    end
  end

  @manifest %{
    "src/app.ts" => %{
      "file" => "assets/app-AAA.js",
      "isEntry" => true,
      "css" => ["assets/app.css"],
      "imports" => []
    }
  }

  defp ctx(overrides \\ []) do
    config = Config.load!([otp_app: :my_app] ++ overrides)
    Context.new(config, env: :test, plugins: [{FakePlugin, []}])
  end

  test "build/2 groups plugin entries by kind and merges the manifest" do
    graph = Graph.build(ctx(), manifest: @manifest)

    assert graph["version"] == 1
    assert graph["app"] == "my_app"
    assert graph["pages"]["Home"] == %{"route" => "/", "source" => "src/routes/+page.svelte"}
    assert graph["routes"]["health"] == %{"path" => "/api/health"}
    assert graph["electric_shapes"]["portfolios"] == %{"table" => "portfolios"}
    assert graph["entries"]["src/app.ts"]["file"] == "/assets/app-AAA.js"
  end

  test "write/2 and load/1 round-trip via graph.json" do
    tmp = Path.join(System.tmp_dir!(), "g_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    context = ctx(static_root: tmp)
    assert {:ok, path} = Graph.write(context, manifest: @manifest)
    assert File.exists?(path)
    assert {:ok, loaded} = Graph.load(context)
    assert loaded["pages"]["Home"]["route"] == "/"
  end

  test "build/2 loads the manifest from disk when none is passed" do
    tmp = Path.join(System.tmp_dir!(), "gm_#{System.unique_integer([:positive])}")
    path = Path.join([tmp, "assets", ".vite", "manifest.json"])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, JSON.encode!(@manifest))
    on_exit(fn -> File.rm_rf!(tmp) end)

    graph = Graph.build(ctx(static_root: tmp))
    assert graph["entries"]["src/app.ts"]["file"] == "/assets/app-AAA.js"
  end

  test "build/2 logs and yields empty groups when a plugin fails to initialise" do
    context = Context.new(Config.load!(otp_app: :my_app), env: :test, plugins: [{FailPlugin, []}])

    {graph, log} = with_log(fn -> Graph.build(context, manifest: @manifest) end)

    assert graph["pages"] == %{}
    assert graph["routes"] == %{}
    assert log =~ "failed to initialise"
  end
end

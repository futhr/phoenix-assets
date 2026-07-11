defmodule PhoenixAssets.Graph.BuilderTest do
  @moduledoc false

  # Asserts global telemetry events, so it runs sync with a unique handler id.
  use ExUnit.Case, async: false

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
      [Entry.new(kind: :route, key: "health", data: %{"path" => "/api/health"})]
    end
  end

  defmodule DuplicatePlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def graph_entries(_, _) do
      [Entry.new(kind: :route, key: "health", data: %{"path" => "/other"})]
    end
  end

  @manifest %{
    "src/app.ts" => %{
      "file" => "assets/app-AAA.js",
      "isEntry" => true,
      "css" => [],
      "imports" => []
    },
    "_vendor.js" => %{"file" => "assets/vendor.js"}
  }

  defp attach(events) do
    parent = self()
    id = "builder-test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      id,
      events,
      fn event, measurements, metadata, _ ->
        send(parent, {:event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(id) end)
  end

  defp ctx(plugins, overrides \\ []) do
    config = Config.load!([otp_app: :my_app] ++ overrides)
    Context.new(config, env: :test, plugins: plugins)
  end

  test "emits [:graph, :degraded] with :plugin_init_failed when a plugin's init/2 fails" do
    attach([[:phoenix_assets, :graph, :degraded]])

    {graph, _} =
      with_log(fn -> Graph.build(ctx([{FailPlugin, []}]), manifest: @manifest) end)

    assert graph["routes"] == %{}
    assert graph["pages"] == %{}

    assert_received {:event, [:phoenix_assets, :graph, :degraded], %{},
                     %{reason: :plugin_init_failed, plugin: FailPlugin, error: :boom}}
  end

  test "emits [:graph, :degraded] with :manifest_unreadable when the manifest is corrupt" do
    attach([[:phoenix_assets, :graph, :degraded]])

    tmp = Path.join(System.tmp_dir!(), "bld_#{System.unique_integer([:positive])}")
    context = ctx([{FakePlugin, []}], static_root: tmp)
    path = Context.manifest_path(context)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, "{ not valid json")
    on_exit(fn -> File.rm_rf!(tmp) end)

    graph = Graph.build(context)

    assert graph["entries"] == %{}
    # A working plugin's entries are unaffected by the manifest problem.
    assert graph["routes"]["health"] == %{"path" => "/api/health"}

    assert_received {:event, [:phoenix_assets, :graph, :degraded], %{},
                     %{reason: :manifest_unreadable, path: ^path}}
  end

  test "stays quiet when no manifest file exists (the normal development case)" do
    attach([[:phoenix_assets, :graph, :degraded]])

    tmp = Path.join(System.tmp_dir!(), "bld_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(tmp) end)

    graph = Graph.build(ctx([{FakePlugin, []}], static_root: tmp))

    assert graph["entries"] == %{}
    refute_received {:event, [:phoenix_assets, :graph, :degraded], _, _}
  end

  test "keeps only isEntry chunks among the manifest entries" do
    graph = Graph.build(ctx([{FakePlugin, []}]), manifest: @manifest)

    assert Map.keys(graph["entries"]) == ["src/app.ts"]
  end

  test "rejects duplicate graph keys instead of silently overwriting one" do
    context = ctx([{FakePlugin, []}, {DuplicatePlugin, []}])

    assert_raise ArgumentError, ~r/duplicate asset graph route key "health"/, fn ->
      Graph.build(context, manifest: @manifest)
    end
  end
end

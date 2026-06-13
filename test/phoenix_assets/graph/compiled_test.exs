defmodule PhoenixAssets.Graph.CompiledTest do
  @moduledoc false

  use ExUnit.Case, async: true

  test "embeds the graph and provides compiled lookups" do
    graph = %{
      "entries" => %{"app" => %{"file" => "/x.js"}},
      "pages" => %{"Home" => %{"route" => "/"}},
      "routes" => %{"health" => %{"path" => "/api/health"}}
    }

    path = Path.join(System.tmp_dir!(), "cg_#{System.unique_integer([:positive])}.json")
    File.write!(path, JSON.encode!(graph))
    on_exit(fn -> File.rm_rf!(path) end)

    Code.eval_string("""
    defmodule PhoenixAssets.Graph.CompiledFixture do
      use PhoenixAssets.Graph.Compiled, graph: #{inspect(path)}
    end
    """)

    fixture = PhoenixAssets.Graph.CompiledFixture

    assert fixture.entry!("app") == %{"file" => "/x.js"}
    assert fixture.page!("Home") == %{"route" => "/"}
    assert fixture.route!("health") == %{"path" => "/api/health"}
    assert_raise KeyError, fn -> fixture.route!("nope") end
  end

  test "raises a clear CompileError when the graph file is not valid JSON" do
    path = Path.join(System.tmp_dir!(), "cg_bad_#{System.unique_integer([:positive])}.json")
    File.write!(path, "{ not valid json")
    on_exit(fn -> File.rm_rf!(path) end)

    assert_raise CompileError, ~r/not valid JSON/, fn ->
      Code.eval_string("""
      defmodule PhoenixAssets.Graph.CompiledBadJSON do
        use PhoenixAssets.Graph.Compiled, graph: #{inspect(path)}
      end
      """)
    end
  end

  test "raises a clear CompileError when the graph file is missing" do
    path = Path.join(System.tmp_dir!(), "cg_missing_#{System.unique_integer([:positive])}.json")

    assert_raise CompileError, ~r/cannot read graph file/, fn ->
      Code.eval_string("""
      defmodule PhoenixAssets.Graph.CompiledMissing do
        use PhoenixAssets.Graph.Compiled, graph: #{inspect(path)}
      end
      """)
    end
  end
end

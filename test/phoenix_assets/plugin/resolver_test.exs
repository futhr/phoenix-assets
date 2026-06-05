defmodule PhoenixAssets.Plugin.ResolverTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.Plugin.Resolver

  defmodule A do
    @moduledoc false
    use PhoenixAssets.Plugin
  end

  defmodule B do
    @moduledoc false
    use PhoenixAssets.Plugin
    depends_on(PhoenixAssets.Plugin.ResolverTest.A)
  end

  defmodule C do
    @moduledoc false
    use PhoenixAssets.Plugin
    after_plugin(PhoenixAssets.Plugin.ResolverTest.B)
  end

  defmodule D do
    @moduledoc false
    use PhoenixAssets.Plugin
  end

  defmodule Cyc1 do
    @moduledoc false
    use PhoenixAssets.Plugin
    depends_on(PhoenixAssets.Plugin.ResolverTest.Cyc2)
  end

  defmodule Cyc2 do
    @moduledoc false
    use PhoenixAssets.Plugin
    depends_on(PhoenixAssets.Plugin.ResolverTest.Cyc1)
  end

  defp order(plugins) do
    {:ok, resolved} = Resolver.resolve(plugins)
    Enum.map(resolved, fn {module, _} -> module end)
  end

  test "orders hard and soft dependencies regardless of input order" do
    assert order([{C, []}, {B, []}, {A, []}]) == [A, B, C]
  end

  test "preserves each plugin's opts" do
    {:ok, [{A, opts} | _]} = Resolver.resolve([{A, [x: 1]}, {B, []}])
    assert opts == [x: 1]
  end

  test "ties break by declaration order" do
    assert order([{D, []}, {A, []}]) == [D, A]
    assert order([{A, []}, {D, []}]) == [A, D]
  end

  test "a soft edge is ignored when its target is absent" do
    assert order([{C, []}]) == [C]
  end

  test "a missing hard dependency is an error" do
    assert Resolver.resolve([{B, []}]) == {:error, {:missing_dependency, B, A}}
  end

  test "a cycle is an error" do
    assert {:error, {:cycle, modules}} = Resolver.resolve([{Cyc1, []}, {Cyc2, []}])
    assert Enum.sort(modules) == Enum.sort([Cyc1, Cyc2])
  end

  test "format_error/1 renders human messages" do
    assert Resolver.format_error({:missing_dependency, B, A}) =~ "depends on"
    assert Resolver.format_error({:cycle, [Cyc1, Cyc2]}) =~ "cycle"
  end
end

defmodule PhoenixAssets.PluginTest do
  @moduledoc false

  use ExUnit.Case, async: true

  defmodule Bare do
    @moduledoc false
    use PhoenixAssets.Plugin
  end

  defmodule Custom do
    @moduledoc false
    use PhoenixAssets.Plugin

    depends_on(PhoenixAssets.PluginTest.Bare)
    after_plugin(PhoenixAssets.PluginTest.Bare)

    def name, do: :custom
    def generated_files(_, _), do: [:file]
  end

  test "default name derives from the module's last segment" do
    assert Bare.name() == :bare
  end

  test "no-op defaults are injected for every callback" do
    assert Bare.init([], %{}) == {:ok, %{}}
    assert Bare.generated_files(%{}, %{}) == []
    assert Bare.vite_config(%{}, %{}) == %{}
    assert Bare.dev_processes(%{}, %{}) == []
    assert Bare.graph_entries(%{}, %{}) == []
    assert Bare.doctor_checks(%{}, %{}) == []
  end

  test "explicit implementations override the defaults" do
    assert Custom.name() == :custom
    assert Custom.generated_files(%{}, %{}) == [:file]
  end

  test "__phoenix_assets_plugin__/0 exposes declared edges" do
    assert Bare.__phoenix_assets_plugin__() == %{module: Bare, depends_on: [], after: []}

    info = Custom.__phoenix_assets_plugin__()
    assert info.depends_on == [Bare]
    assert info.after == [Bare]
  end
end

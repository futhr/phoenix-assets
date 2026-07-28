defmodule PhoenixAssets.Presets.SvelteTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Presets}

  defmodule CustomPreset do
    @moduledoc false
    use PhoenixAssets.Preset

    integration(PhoenixAssets.Tailwind)
  end

  @plugins [
    PhoenixAssets.SvelteKit,
    PhoenixAssets.Tailwind,
    PhoenixAssets.Storybook,
    PhoenixAssets.Electric,
    PhoenixAssets.Enums,
    PhoenixAssets.Commands,
    PhoenixAssets.Session,
    PhoenixAssets.PubSub,
    PhoenixAssets.Localize,
    PhoenixAssets.Types,
    PhoenixAssets.Typespec
  ]

  test "the default preset composes the full Svelte stack" do
    mods = Enum.map(Presets.Svelte.plugins(), fn {module, _} -> module end)
    assert Enum.sort(mods) == Enum.sort(@plugins)
  end

  test "Storybook is ordered after SvelteKit and Tailwind" do
    mods = Enum.map(Presets.Svelte.plugins(), fn {module, _} -> module end)

    sveltekit = Enum.find_index(mods, &(&1 == PhoenixAssets.SvelteKit))
    tailwind = Enum.find_index(mods, &(&1 == PhoenixAssets.Tailwind))
    storybook = Enum.find_index(mods, &(&1 == PhoenixAssets.Storybook))

    assert sveltekit < storybook
    assert tailwind < storybook
  end

  test "is the implicit default when the host configures no :preset" do
    config = Config.load!(otp_app: :my_app)
    assert config.preset == nil

    mods = Enum.map(Config.preset_plugins(config), fn {module, _} -> module end)
    assert Enum.sort(mods) == Enum.sort(@plugins)
  end

  test "an explicit :preset overrides the default" do
    config = Config.load!(otp_app: :my_app, preset: CustomPreset)
    assert Config.preset_plugins(config) == [{PhoenixAssets.Tailwind, []}]
  end
end

defmodule PhoenixAssets.StorybookTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context, Storybook}

  defp ctx(overrides \\ []) do
    Context.new(Config.load!([otp_app: :my_app] ++ overrides), env: :test)
  end

  test "contributes a supervised storybook dev process on the given port" do
    {:ok, state} = Storybook.init([port: 6006], ctx())
    assert [%{id: :storybook, port: 6006}] = Storybook.dev_processes(ctx(), state)
  end

  test "execs the storybook binary directly, never a package-manager wrapper" do
    {:ok, state} = Storybook.init([], ctx())
    [%{command: [bin | args]}] = Storybook.dev_processes(ctx(), state)

    assert bin =~ "node_modules/.bin/storybook"
    assert ["dev", "-p", "6006", "--no-open"] = args
  end

  test "config :dev, storybook: overrides preset opts (port and enabled)" do
    context = ctx(dev: [storybook: [port: 7007]])
    {:ok, state} = Storybook.init([port: 6006], context)
    assert [%{port: 7007, command: command}] = Storybook.dev_processes(context, state)
    assert "7007" in command

    disabled = ctx(dev: [storybook: [enabled: false]])
    {:ok, state} = Storybook.init([], disabled)
    assert Storybook.dev_processes(disabled, state) == []
  end

  test "depends on SvelteKit" do
    assert PhoenixAssets.SvelteKit in Storybook.__phoenix_assets_plugin__().depends_on
  end
end

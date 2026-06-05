defmodule PhoenixAssets.StorybookTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context, Storybook}

  defp ctx, do: Context.new(Config.load!(otp_app: :my_app), env: :test)

  test "contributes a supervised storybook dev process on the given port" do
    {:ok, state} = Storybook.init([port: 6006], ctx())
    assert [%{id: :storybook, port: 6006}] = Storybook.dev_processes(ctx(), state)
  end

  test "depends on SvelteKit" do
    assert PhoenixAssets.SvelteKit in Storybook.__phoenix_assets_plugin__().depends_on
  end
end

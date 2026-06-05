defmodule PhoenixAssets.SvelteKitTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context, SvelteKit}

  defp ctx, do: Context.new(Config.load!(otp_app: :my_app), env: :test)

  test "contributes a supervised vite dev process" do
    {:ok, state} = SvelteKit.init([], ctx())
    assert [%{id: :vite}] = SvelteKit.dev_processes(ctx(), state)
  end

  test "generates the env contract" do
    {:ok, state} = SvelteKit.init([], ctx())
    kinds = ctx() |> SvelteKit.generated_files(state) |> Enum.map(& &1.kind)
    assert :env in kinds
  end
end

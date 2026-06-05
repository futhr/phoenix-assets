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

  test "graph_entries collapses a parameter-only page route to the Index key" do
    tmp = Path.join(System.tmp_dir!(), "sk_#{System.unique_integer([:positive])}")
    page = Path.join([tmp, "src", "routes", "[slug]", "+page.svelte"])
    File.mkdir_p!(Path.dirname(page))
    File.write!(page, "")
    on_exit(fn -> File.rm_rf!(tmp) end)

    context = Context.new(Config.load!(otp_app: :my_app, asset_root: tmp), env: :test)
    {:ok, state} = SvelteKit.init([], context)

    assert [entry] = SvelteKit.graph_entries(context, state)
    assert entry.key == "Index"
    assert entry.data == %{"route" => "/:slug"}
  end
end

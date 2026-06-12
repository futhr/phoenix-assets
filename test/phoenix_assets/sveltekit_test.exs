defmodule PhoenixAssets.SvelteKitTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context, SvelteKit}

  defp ctx, do: Context.new(Config.load!(otp_app: :my_app), env: :test)

  test "contributes a supervised vite dev process" do
    {:ok, state} = SvelteKit.init([], ctx())
    assert [%{id: :vite}] = SvelteKit.dev_processes(ctx(), state)
  end

  test "the default vite command carries the configured host and port" do
    config = Config.load!(otp_app: :my_app, dev: [vite: [host: "0.0.0.0", port: 5180]])
    context = Context.new(config, env: :test)

    {:ok, state} = SvelteKit.init([], context)
    [%{port: 5180, command: command}] = SvelteKit.dev_processes(context, state)

    assert hd(command) =~ "node_modules/.bin/vite"
    assert ["--host", "0.0.0.0", "--port", "5180", "--strictPort"] = tl(command)
  end

  test "generates the env contract" do
    {:ok, state} = SvelteKit.init([], ctx())
    kinds = ctx() |> SvelteKit.generated_files(state) |> Enum.map(& &1.kind)
    assert :env in kinds
  end

  test "param segments contribute to the page key" do
    tmp = Path.join(System.tmp_dir!(), "sk_#{System.unique_integer([:positive])}")
    page = Path.join([tmp, "src", "routes", "[slug]", "+page.svelte"])
    File.mkdir_p!(Path.dirname(page))
    File.write!(page, "")
    on_exit(fn -> File.rm_rf!(tmp) end)

    context = Context.new(Config.load!(otp_app: :my_app, asset_root: tmp), env: :test)
    {:ok, state} = SvelteKit.init([], context)

    assert [entry] = SvelteKit.graph_entries(context, state)
    assert entry.key == "BySlug"
    assert entry.data == %{"route" => "/:slug"}
  end

  test "a param route and its static sibling get distinct page keys" do
    tmp = Path.join(System.tmp_dir!(), "sk_#{System.unique_integer([:positive])}")

    for dir <- ["users", "users/[id]"] do
      page = Path.join([tmp, "src", "routes", dir, "+page.svelte"])
      File.mkdir_p!(Path.dirname(page))
      File.write!(page, "")
    end

    on_exit(fn -> File.rm_rf!(tmp) end)

    context = Context.new(Config.load!(otp_app: :my_app, asset_root: tmp), env: :test)
    {:ok, state} = SvelteKit.init([], context)
    keys = context |> SvelteKit.graph_entries(state) |> Enum.map(& &1.key) |> Enum.sort()

    assert keys == ["Users", "UsersById"]
  end
end

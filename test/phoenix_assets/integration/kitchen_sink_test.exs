defmodule PhoenixAssets.Integration.KitchenSinkTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias PhoenixAssets.{Config, Context, Doctor, Engine, Generated}
  alias PhoenixAssets.Graph.Builder

  defmodule Controller do
    @moduledoc false
    def init(opts), do: opts
    def call(conn, _), do: conn
  end

  defmodule Router do
    @moduledoc false
    use Phoenix.Router

    alias PhoenixAssets.Integration.KitchenSinkTest.Controller

    get("/api/health", Controller, :health)
    get("/shapes/portfolios", Controller, :portfolios)
    get("/shapes/users/:user_id/portfolios", Controller, :user_portfolios)
  end

  defmodule Shapes do
    @moduledoc false
    use PhoenixAssets.Electric.Shapes

    shape(:portfolios, route: "/shapes/portfolios", type: "PortfolioRow")

    shape(:user_portfolios,
      route: "/shapes/users/:user_id/portfolios",
      type: "PortfolioRow",
      params: [:user_id]
    )
  end

  defmodule Topics do
    @moduledoc false
    use PhoenixAssets.PubSub.Topics

    topic(:portfolio,
      pattern: "portfolio:{id}",
      events: [updated: "PortfolioRow", deleted: %{id: :string}]
    )
  end

  defmodule Types do
    @moduledoc false
    use PhoenixAssets.Types.Schema

    type("PortfolioRow", resource: PhoenixAssets.TestSupport.Portfolio, only: :public)
    type("KitchenSinkRow", resource: PhoenixAssets.TestSupport.KitchenSink, only: :public)
  end

  setup do
    root = Path.join(System.tmp_dir!(), "pa_ks_#{System.unique_integer([:positive])}")

    for dir <- ["src/routes/about", "src/routes/users/[id]"] do
      File.mkdir_p!(Path.join(root, dir))
    end

    File.write!(Path.join(root, "svelte.config.js"), "export default {}\n")
    File.write!(Path.join(root, "package.json"), "{}\n")
    File.write!(Path.join(root, "src/app.css"), "@import \"tailwindcss\";\n")
    File.write!(Path.join(root, "src/routes/+page.svelte"), "")
    File.write!(Path.join(root, "src/routes/about/+page.svelte"), "")
    File.write!(Path.join(root, "src/routes/users/+page.svelte"), "")
    File.write!(Path.join(root, "src/routes/users/[id]/+page.svelte"), "")

    on_exit(fn -> File.rm_rf!(root) end)

    config =
      Config.load!(
        otp_app: :phoenix_assets,
        router: Router,
        asset_root: root,
        stack: [shapes: Shapes, topics: Topics, types: Types]
      )

    %{ctx: Context.new(config, env: :test, plugins: Config.preset_plugins(config)), root: root}
  end

  test "the default preset resolves the full Svelte stack", %{ctx: ctx} do
    mods = Enum.map(ctx.plugins, fn {module, _} -> module end)

    assert length(mods) == 7
    assert PhoenixAssets.SvelteKit in mods
    assert PhoenixAssets.Electric in mods
    assert PhoenixAssets.Types in mods
  end

  test "initialises every plugin without error", %{ctx: ctx} do
    assert {:ok, initialized} = Engine.init_plugins(ctx)
    assert length(initialized) == 7
  end

  test "generates all six contracts and excludes sensitive/private fields", %{
    ctx: ctx,
    root: root
  } do
    assert {:ok, %{written: written}} = Generated.generate(ctx)
    gen = Path.join(root, "src/generated")

    for name <- ~w(routes.ts env.ts electric.ts pubsub.ts locales.ts types.ts) do
      assert File.exists?(Path.join(gen, name)), "expected #{name} to be generated"
    end

    electric = File.read!(Path.join(gen, "electric.ts"))
    assert electric =~ ~s|import { ShapeStream } from "@electric-sql/client"|

    assert electric =~
             "userPortfolios: (params: { user_id: string | number } " <>
               "& Record<string, string | number>)"

    assert electric =~ ~s|createShapeUrl("/shapes/users/:user_id/portfolios", params)|
    assert electric =~ "headers: authHeaders()"

    pubsub = File.read!(Path.join(gen, "pubsub.ts"))
    assert pubsub =~ "export const topics"
    assert pubsub =~ ~s|"portfolio:updated"|
    assert pubsub =~ ~s|"portfolio:deleted"|

    routes = File.read!(Path.join(gen, "routes.ts"))
    assert routes =~ "health: () =>"

    types = File.read!(Path.join(gen, "types.ts"))
    assert types =~ "export type PortfolioRow"
    assert types =~ "export type KitchenSinkRow"
    # sensitive + non-public fields must never reach the generated client type.
    refute types =~ "secret_token"
    refute types =~ "internal_note"
    refute types =~ "api_secret"
    refute types =~ "internal_flag"

    assert "src/generated/types.ts" in written
  end

  test "contributes vite and storybook dev processes", %{ctx: ctx} do
    {:ok, initialized} = Engine.init_plugins(ctx)
    ids = ctx |> Engine.collect(initialized, :dev_processes) |> Enum.map(& &1.id)

    assert :vite in ids
    assert :storybook in ids
  end

  test "builds the asset graph from discovered pages, shapes, and topics", %{ctx: ctx} do
    graph = Builder.build(ctx)

    assert graph["version"] == 1
    assert graph["app"] == "phoenix_assets"
    assert Map.has_key?(graph["pages"], "Index")
    assert Map.has_key?(graph["pages"], "About")
    # A param route never displaces its static sibling in the page map.
    assert Map.has_key?(graph["pages"], "Users")
    assert Map.has_key?(graph["pages"], "UsersById")
    assert Map.has_key?(graph["electric_shapes"], "portfolios")
    assert Map.has_key?(graph["electric_shapes"], "user_portfolios")
    assert Map.has_key?(graph["pubsub_topics"], "portfolio")
  end

  test "doctor runs every plugin's checks without unexpected errors", %{ctx: ctx} do
    {status, results} = Doctor.run(ctx)
    groups = results |> Enum.map(fn {check, _} -> check.group end) |> Enum.uniq()

    refute status == :error
    assert :sveltekit in groups
    assert :electric in groups
    assert :tailwind in groups
  end

  test "regeneration is byte-identical and writes nothing", %{ctx: ctx} do
    assert {:ok, _} = Generated.generate(ctx)
    assert {:ok, %{written: [], unchanged: unchanged}} = Generated.generate(ctx)
    assert length(unchanged) >= 5
  end
end

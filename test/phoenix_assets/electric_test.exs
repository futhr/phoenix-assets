defmodule PhoenixAssets.ElectricTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context, Electric}

  defmodule Shapes do
    @moduledoc false
    use PhoenixAssets.Electric.Shapes

    shape(:public_portfolios, route: "/shapes/portfolios", type: "PortfolioRow")

    shape(:user_portfolios,
      route: "/shapes/users/:user_id/portfolios",
      type: "PortfolioRow",
      params: [:user_id]
    )
  end

  defmodule EmptyShapes do
    @moduledoc false
    use PhoenixAssets.Electric.Shapes
  end

  defmodule RouteEdgeShapes do
    @moduledoc false
    # A plain declaration module (no DSL): the DSL rejects a missing :route at
    # compile time, but the plugin must stay defensive against hand-rolled
    # modules that bypass it.
    def __phoenix_assets_shapes__ do
      [no_route: [type: "GhostRow"], ghost: [route: "/shapes/ghost", type: "GhostRow"]]
    end
  end

  defmodule Stub do
    @moduledoc false
    def init(opts), do: opts
    def call(conn, _), do: conn
  end

  defmodule Router do
    @moduledoc false
    use Phoenix.Router

    get("/shapes/portfolios", PhoenixAssets.ElectricTest.Stub, :portfolios)
  end

  defp ctx, do: Context.new(Config.load!(otp_app: :my_app), env: :test)

  defp render do
    {:ok, state} = Electric.init([shapes: Shapes], ctx())
    [file] = Electric.generated_files(ctx(), state)
    assert file.kind == :electric
    IO.iodata_to_binary(file.contents)
  end

  test "imports the Electric client, the svelte auth/url helpers, and the row types" do
    out = render()
    assert out =~ ~s|import { ShapeStream } from "@electric-sql/client"|
    assert out =~ ~s|import { authHeaders, createShapeUrl } from "@phoenix-assets/svelte"|
    assert out =~ ~s|import type { PortfolioRow } from "$phoenix/types"|
  end

  test "generates a typed, auth-bearing factory per shape" do
    out = render()

    assert out =~ "publicPortfolios: (params: Record<string, string | number> = {}) =>"
    assert out =~ ~s|createShapeUrl("/shapes/portfolios", params)|
    assert out =~ ~s|createShapeUrl("/shapes/users/:user_id/portfolios", params)|

    # Every factory must carry auth so a tenant-scoped shape can never be
    # requested anonymously -- the security guarantee of the generated client.
    assert out =~ "headers: authHeaders()"
    refute out =~ ~s|{ url: "/shapes/portfolios" }|
  end

  test "route placeholders become required, typed param keys" do
    out = render()

    assert out =~
             "userPortfolios: (params: { user_id: string | number } " <>
               "& Record<string, string | number>) =>"
  end

  test "a nil shapes module contributes no files, entries, or checks" do
    assert Electric.generated_files(ctx(), %{module: nil}) == []
    assert Electric.graph_entries(ctx(), %{module: nil}) == []
    assert Electric.doctor_checks(ctx(), %{module: nil}) == []
  end

  test "an empty shapes module omits the row-type import line" do
    {:ok, state} = Electric.init([shapes: EmptyShapes], ctx())
    [file] = Electric.generated_files(ctx(), state)
    out = IO.iodata_to_binary(file.contents)

    refute out =~ "$phoenix/types"
    assert out =~ "export const shapes = {\n} as const"
  end

  test "doctor checks flag a missing :route and a route absent from the router" do
    router_ctx = Context.new(Config.load!(otp_app: :my_app, router: Router), env: :test)
    {:ok, state} = Electric.init([shapes: RouteEdgeShapes], router_ctx)

    results = router_ctx |> Electric.doctor_checks(state) |> Enum.map(& &1.run.(router_ctx))
    messages = Enum.map(results, & &1.message)

    assert Enum.all?(results, &(&1.status == :error))
    assert Enum.any?(messages, &(&1 =~ "has no :route"))
    assert Enum.any?(messages, &(&1 =~ "is not in the router"))
  end

  test "doctor check warns when no router is configured to validate against" do
    {:ok, state} = Electric.init([shapes: Shapes], ctx())
    [result | _] = ctx() |> Electric.doctor_checks(state) |> Enum.map(& &1.run.(ctx()))

    assert result.status == :warn
    assert result.message =~ "no router configured"
  end
end

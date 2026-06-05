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
    use PhoenixAssets.Electric.Shapes

    shape(:no_route, type: "GhostRow")
    shape(:ghost, route: "/shapes/ghost", type: "GhostRow")
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

  test "imports the Electric client and the row types" do
    out = render()
    assert out =~ ~s|import { ShapeStream } from "@electric-sql/client"|
    assert out =~ ~s|import type { PortfolioRow } from "$phoenix/types"|
  end

  test "generates a typed factory per shape, with URL params" do
    out = render()

    assert out =~
             ~s|publicPortfolios: () => new ShapeStream<PortfolioRow>({ url: "/shapes/portfolios" })|

    assert out =~ "userPortfolios: (userId: string | number) =>"
    assert out =~ "encodeURIComponent(String(userId))"
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

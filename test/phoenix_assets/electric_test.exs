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
end

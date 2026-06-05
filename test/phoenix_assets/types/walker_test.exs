defmodule PhoenixAssets.Types.WalkerTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.TestSupport.Portfolio
  alias PhoenixAssets.Types.Walker

  defp render(opts) do
    Walker.render([{"PortfolioRow", [resource: Portfolio] ++ opts}])
  end

  test "maps Ash attribute types to TypeScript" do
    ts = render(only: :public)

    assert ts =~ "export type PortfolioRow = {"
    assert ts =~ "title: string"
    assert ts =~ ~s("public" | "private" | "unlisted")
    assert ts =~ "view_count: number"
    assert ts =~ "hourly_rate: string | null"
    assert ts =~ "skills: Array<string>"
    assert ts =~ "metadata: Record<string, unknown>"
    assert ts =~ "inserted_at: string"
  end

  test "excludes sensitive and non-public attributes by default" do
    ts = render(only: :public)

    refute ts =~ "secret_token"
    refute ts =~ "internal_note"
  end

  test "omit drops an otherwise-included attribute" do
    ts = render(only: :public, omit: [:view_count])
    refute ts =~ "view_count"
  end

  test "only: :all includes non-public attributes (still excluding sensitive)" do
    ts = render(only: :all)

    assert ts =~ "internal_note"
    refute ts =~ "secret_token"
  end

  test "is deterministic across runs" do
    assert render(only: :public) == render(only: :public)
  end
end

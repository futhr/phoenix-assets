defmodule PhoenixAssets.Types.WalkerTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.TestSupport.{Portfolio, WalkerEdge}
  alias PhoenixAssets.Types.Walker

  defp render(opts) do
    Walker.render([{"PortfolioRow", [resource: Portfolio] ++ opts}])
  end

  defp render_edge(opts) do
    Walker.render([{"EdgeRow", [resource: WalkerEdge] ++ opts}])
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

  test "expose pulls in an otherwise-excluded (non-public) attribute" do
    assert render_edge(only: :public, expose: [:hidden]) =~ "hidden: string | null"
    refute render_edge(only: :public) =~ "hidden:"
  end

  test "a bare atom attribute without one_of maps to string" do
    assert render_edge(only: :public) =~ "kind: string"
  end

  test "calculations are resolved through their declared type" do
    assert render_edge(only: :public, calculations: [:label]) =~ "label: string"
  end

  test "an unknown calculation name degrades to unknown rather than crashing" do
    assert render_edge(only: :public, calculations: [:does_not_exist]) =~ "does_not_exist: unknown"
  end
end

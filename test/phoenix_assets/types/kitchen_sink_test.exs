defmodule PhoenixAssets.Types.KitchenSinkTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.TestSupport.KitchenSink
  alias PhoenixAssets.Types.Walker

  defp render, do: Walker.render([{"KitchenSinkRow", [resource: KitchenSink, only: :public]}])

  test "maps scalar attribute types" do
    out = render()

    assert out =~ "name: string"
    assert out =~ "slug: string"
    assert out =~ "count: number"
    assert out =~ "ratio: number"
    assert out =~ "price: string | null"
    assert out =~ "active: boolean"
    assert out =~ "due_on: string"
    assert out =~ "created_at: string"
  end

  test "maps atoms with one_of to string-literal unions" do
    assert render() =~ ~s("draft" | "published")
  end

  test "maps arrays and open maps" do
    out = render()
    assert out =~ "tags: Array<string>"
    assert out =~ "meta: Record<string, unknown>"
  end

  test "maps a map with field constraints to a typed object" do
    out = render()
    assert out =~ "dimensions: {"
    assert out =~ "width: number"
    assert out =~ "height: number"
  end

  test "recurses embedded resources into a nested object" do
    out = render()
    assert out =~ "street: string"
    assert out =~ "zip: string"
    assert out =~ "address:"
    assert out =~ "| null"
  end

  test "resolves a NewType to its subtype" do
    assert render() =~ "priority: string"
  end

  test "maps union types to a TypeScript union" do
    assert render() =~ "payload: string | number"
  end

  test "excludes sensitive and non-public attributes" do
    out = render()
    refute out =~ "api_secret"
    refute out =~ "internal_flag"
  end
end

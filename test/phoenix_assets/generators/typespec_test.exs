defmodule PhoenixAssets.Generators.TypespecTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.Generators.{TS, Typespec}
  alias PhoenixAssets.Test.TypespecFixture

  test "renders a configured discriminated typespec union through shared TS helpers" do
    assert {:ok, output} =
             Typespec.render(TypespecFixture,
               root_name: "Event",
               discriminator_name: "EventMode",
               types: [:created, :removed]
             )

    assert output =~ TS.header()
    assert output =~ "export type EventMode = \"created\" | \"removed\""
    assert output =~ "export type Event =\n  | Created\n  | Removed"
    assert output =~ "userId: number"
    assert output =~ "labels: string[]"
    assert output =~ ~s(reason: string | null)
  end

  test "writes the rendered artifact" do
    output = Path.join(System.tmp_dir!(), "phoenix-assets-typespec-#{System.unique_integer()}.ts")
    on_exit(fn -> File.rm(output) end)

    assert :ok = Typespec.write(TypespecFixture, output, root_name: "Event")
    assert File.read!(output) =~ "export type Event"
  end
end

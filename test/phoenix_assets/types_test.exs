defmodule PhoenixAssets.TypesTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context, Types}

  defmodule Schema do
    @moduledoc false
    use PhoenixAssets.Types.Schema

    type("PortfolioRow", resource: PhoenixAssets.TestSupport.Portfolio, only: :public)
  end

  defmodule GatedSchema do
    @moduledoc false
    use PhoenixAssets.Types.Schema

    type("GatedRow", resource: PhoenixAssets.TestSupport.Gated, only: :public)
  end

  defp ctx, do: Context.new(Config.load!(otp_app: :my_app), env: :test)

  test "generates types.ts from declarations" do
    {:ok, state} = Types.init([types: Schema], ctx())
    [file] = Types.generated_files(ctx(), state)

    assert file.kind == :types
    assert IO.iodata_to_binary(file.contents) =~ "export type PortfolioRow"
  end

  test "field-policy doctor check passes when the resource has no field policies" do
    {:ok, state} = Types.init([types: Schema], ctx())
    [check] = Types.doctor_checks(ctx(), state)

    assert check.run.(ctx()).status == :ok
  end

  test "field-policy doctor check warns when an exposed field is policy-gated" do
    {:ok, state} = Types.init([types: GatedSchema], ctx())
    [check] = Types.doctor_checks(ctx(), state)
    result = check.run.(ctx())

    assert result.status == :warn
    assert result.message =~ "email"
    assert result.hint =~ ":omit"
  end

  test "a nil types module generates nothing" do
    assert Types.generated_files(ctx(), %{module: nil}) == []
  end
end

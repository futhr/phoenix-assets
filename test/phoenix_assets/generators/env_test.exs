defmodule PhoenixAssets.Generators.EnvTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context}
  alias PhoenixAssets.Generators.Env

  defp generate(expose) do
    ctx = Context.new(Config.load!(otp_app: :my_app, env: [expose: expose]))
    ctx |> Env.generate() |> Map.fetch!(:contents) |> IO.iodata_to_binary()
  end

  test "emits allow-listed values as camelCase consts" do
    ts = generate(app_name: "MyApp", public_api_base: "/api")

    assert ts =~ ~s(appName: "MyApp")
    assert ts =~ ~s(publicApiBase: "/api")
    assert ts =~ "as const"
  end

  test "sorts keys deterministically" do
    ts = generate(z_last: 1, a_first: 2)

    assert elem(:binary.match(ts, "aFirst"), 0) < elem(:binary.match(ts, "zLast"), 0)
  end

  test "emits an empty object when nothing is exposed" do
    assert generate([]) =~ "export const env = {"
  end

  test "rejects keys that collide after camelizing" do
    assert_raise ArgumentError, ~r/both generate "userId"/, fn ->
      generate(user_id: 1, userId: 2)
    end
  end
end

defmodule PhoenixAssets.ContextTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context}

  defp ctx(overrides \\ []) do
    Context.new(Config.load!([otp_app: :my_app] ++ overrides), env: :test)
  end

  test "new/2 hoists the most-used config fields onto the context" do
    context = ctx()

    assert context.otp_app == :my_app
    assert context.asset_root == "assets"
    assert context.package_manager == :pnpm
    assert context.env == :test
    assert %Config{} = context.config
  end

  test "asset_path/2 joins a relative path onto the asset root" do
    assert Context.asset_path(ctx(), "src/app.ts") == "assets/src/app.ts"
    assert Context.asset_path(ctx(asset_root: "web"), "main.ts") == "web/main.ts"
  end

  test "generated_path/2 joins onto the generated dir under the asset root" do
    assert Context.generated_path(ctx(), "routes.ts") == "assets/src/generated/routes.ts"
    assert Context.generated_path(ctx()) == "assets/src/generated"
  end

  test "manifest_path/1 honours the :vite_manifest override, else the default" do
    assert Context.manifest_path(ctx()) == "priv/static/assets/.vite/manifest.json"

    overridden = ctx(static_root: "priv/static", build: [vite_manifest: "/tmp/custom.json"])
    assert Context.manifest_path(overridden) == "/tmp/custom.json"
  end
end

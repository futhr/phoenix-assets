defmodule PhoenixAssets.ConfigTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.Config

  describe "load!/1" do
    test "applies defaults" do
      config = Config.load!(otp_app: :my_app)

      assert config.otp_app == :my_app
      assert config.asset_root == "assets"
      assert config.static_root == "priv/static"
      assert config.static_assets_path == "/assets"
      assert config.generated_dir == "src/generated"
      assert config.package_manager == :pnpm
      assert config.js_runtime == :node
      assert config.ssr_runtime == :node
    end

    test "captures nested sub-configs" do
      config =
        Config.load!(
          otp_app: :my_app,
          dev: [enabled: true],
          build: [fail_on_missing_entry: true],
          env: [expose: [:app_name]],
          dev_intelligence: [tidewave: true]
        )

      assert config.dev == [enabled: true]
      assert config.build == [fail_on_missing_entry: true]
      assert config.env_expose == [expose: [:app_name]]
      assert config.dev_intelligence == [tidewave: true]
    end

    test "requires otp_app" do
      assert_raise NimbleOptions.ValidationError, fn -> Config.load!([]) end
    end

    test "rejects an invalid package_manager" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.load!(otp_app: :my_app, package_manager: :yarn)
      end
    end
  end
end

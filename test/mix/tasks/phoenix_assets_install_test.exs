defmodule Mix.Tasks.PhoenixAssets.InstallTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import Igniter.Test

  # Running the installer evaluates the generated `config :phoenix_assets, ...`,
  # which would leak `:router`/`:endpoint`/`:otp_app` into the application env and
  # break sibling Mix-task tests. Snapshot and restore it around the test.
  setup do
    saved = Application.get_all_env(:phoenix_assets)

    on_exit(fn ->
      for {key, _} <- Application.get_all_env(:phoenix_assets) do
        Application.delete_env(:phoenix_assets, key)
      end

      for {key, value} <- saved, do: Application.put_env(:phoenix_assets, key, value)
    end)

    :ok
  end

  test "configures phoenix_assets and scaffolds the frontend entry files" do
    igniter =
      phx_test_project()
      |> Igniter.compose_task("phoenix_assets.install", [])

    igniter
    |> assert_creates("assets/vite.config.ts")
    |> assert_creates("assets/src/app.css")
    |> assert_has_patch("config/config.exs", """
    + |config :phoenix_assets,
    """)
  end
end

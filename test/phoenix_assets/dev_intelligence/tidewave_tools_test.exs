defmodule PhoenixAssets.DevIntelligence.TidewaveToolsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias PhoenixAssets.DevIntelligence.TidewaveTools
  alias PhoenixAssets.DevServer

  setup do
    root = Path.join(System.tmp_dir!(), "pa_tw_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "node_modules/.bin"))
    saved = Application.get_all_env(:phoenix_assets)

    on_exit(fn ->
      for {key, _} <- Application.get_all_env(:phoenix_assets) do
        Application.delete_env(:phoenix_assets, key)
      end

      for {key, value} <- saved, do: Application.put_env(:phoenix_assets, key, value)
      File.rm_rf!(root)
    end)

    Application.put_env(:phoenix_assets, :otp_app, :phoenix_assets)
    Application.put_env(:phoenix_assets, :asset_root, root)
    :ok
  end

  test "status/0 reports the state of each supervised dev process" do
    start_supervised!(DevServer)
    status = TidewaveTools.status()

    assert is_atom(status.vite)
    assert is_atom(status.storybook)
  end

  test "logs/2 returns the recent output lines for a process" do
    start_supervised!(DevServer)
    DevServer.log_line("hello vite", :vite)

    assert TidewaveTools.logs(:vite) == ["hello vite"]
  end

  test "doctor/1 runs the asset-pipeline diagnostics against the default preset" do
    {status, results} = TidewaveTools.doctor()

    refute status == :error
    assert is_list(results)
  end
end

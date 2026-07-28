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
    Application.put_env(:phoenix_assets, :dev_intelligence, tidewave: true)
    :ok
  end

  describe "without the :tidewave opt-in" do
    setup do
      Application.delete_env(:phoenix_assets, :dev_intelligence)
      :ok
    end

    test "every entry point reports itself disabled rather than acting" do
      refute TidewaveTools.enabled?()
      assert TidewaveTools.status() == {:error, :disabled}
      assert TidewaveTools.logs(:vite) == {:error, :disabled}
      assert TidewaveTools.restart(:vite) == {:error, :disabled}
      assert TidewaveTools.doctor() == {:error, :disabled}
    end

    test "an explicit false is not an opt-in either" do
      Application.put_env(:phoenix_assets, :dev_intelligence, tidewave: false)

      refute TidewaveTools.enabled?()
    end
  end

  test "status/0 is empty when the dev supervisor is not running" do
    assert TidewaveTools.status() == %{}
  end

  test "status/0 enumerates the dev supervisor's actual daemons" do
    child = Supervisor.child_spec({Agent, fn -> :ok end}, id: :vite)

    start_supervised!(%{
      id: :devsup_standin,
      start:
        {Supervisor, :start_link,
         [[child], [strategy: :one_for_one, name: PhoenixAssets.DevSupervisor]]}
    })

    assert TidewaveTools.status() == %{vite: :running}
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

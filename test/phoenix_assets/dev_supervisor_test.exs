defmodule PhoenixAssets.DevSupervisorTest do
  @moduledoc false

  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias PhoenixAssets.{Config, Context, DevProcess, DevServer, DevSupervisor}

  defmodule VitePlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def dev_processes(ctx, _) do
      [DevProcess.new(id: :fake_vite, command: ["true"], cd: ctx.asset_root)]
    end
  end

  defmodule FailPlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def init(_, _), do: {:error, :boom}
  end

  defp ctx(plugins) do
    Context.new(Config.load!(otp_app: :my_app), env: :dev, plugins: plugins)
  end

  test "starts the dev server and watcher when there are no dev processes" do
    start_supervised!({DevSupervisor, ctx: ctx([]), watch_dirs: []})

    assert is_pid(Process.whereis(DevServer))
    assert is_pid(Process.whereis(PhoenixAssets.Generated.Watcher))
    assert DevServer.status(:nonexistent) == :unknown
  end

  test "init/1 builds a daemon child spec for each enabled dev process" do
    {:ok, {_, specs}} =
      DevSupervisor.init(ctx: ctx([{VitePlugin, []}]), watch_dirs: [])

    ids = Enum.map(specs, & &1.id)
    assert :fake_vite in ids
    assert DevServer in ids
  end

  test "init/1 logs and starts no daemons when a plugin fails to initialise" do
    {{:ok, {_, specs}}, log} =
      with_log(fn -> DevSupervisor.init(ctx: ctx([{FailPlugin, []}]), watch_dirs: []) end)

    refute :fake_vite in Enum.map(specs, & &1.id)
    assert log =~ "failed to initialise"
    assert log =~ "FailPlugin"
  end
end

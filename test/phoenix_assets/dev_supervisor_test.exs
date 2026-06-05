defmodule PhoenixAssets.DevSupervisorTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias PhoenixAssets.{Config, Context, DevServer, DevSupervisor}

  test "starts the dev server and watcher when there are no dev processes" do
    ctx = Context.new(Config.load!(otp_app: :my_app), env: :dev, plugins: [])
    start_supervised!({DevSupervisor, ctx: ctx, watch_dirs: []})

    assert is_pid(Process.whereis(DevServer))
    assert is_pid(Process.whereis(PhoenixAssets.Generated.Watcher))
    assert DevServer.status(:nonexistent) == :unknown
  end
end

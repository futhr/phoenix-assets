defmodule PhoenixAssets.DevServerTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias PhoenixAssets.DevServer

  test "buffers and returns log lines per id, oldest first" do
    start_supervised!(DevServer)

    DevServer.log_line("line 1", :vite)
    DevServer.log_line("line 2", :vite)
    DevServer.log_line("sb line", :storybook)

    assert DevServer.logs(:vite) == ["line 1", "line 2"]
    assert DevServer.logs(:storybook) == ["sb line"]
    assert DevServer.logs(:unknown) == []
  end

  test "logs/2 honours the limit, keeping the most recent" do
    start_supervised!(DevServer)

    for n <- 1..5, do: DevServer.log_line("line #{n}", :vite)

    assert DevServer.logs(:vite, limit: 2) == ["line 4", "line 5"]
    assert DevServer.logs(:vite, limit: 0) == []
    assert_raise ArgumentError, fn -> DevServer.logs(:vite, limit: -1) end
  end

  test "log_line/2 is a no-op when no server is running" do
    refute Process.whereis(DevServer)
    assert DevServer.log_line("x", :vite) == :ok
  end

  test "status/1 is :unknown when the supervisor is absent" do
    assert DevServer.status(:vite) == :unknown
  end

  test "restart/1, stop/1, and logs/2 degrade when nothing is running" do
    refute Process.whereis(DevServer)
    refute Process.whereis(PhoenixAssets.DevSupervisor)

    assert DevServer.restart(:vite) == {:error, :not_running}
    assert DevServer.stop(:vite) == {:error, :not_running}
    assert DevServer.logs(:vite) == []
  end

  describe "status/restart/stop against a supervised child" do
    setup do
      # DevServer talks to the process registered as PhoenixAssets.DevSupervisor;
      # stand in a bare supervisor with a known child id so the operator surface
      # can be exercised without spawning real OS daemons.
      child = Supervisor.child_spec({Agent, fn -> :ok end}, id: :dummy)

      start_supervised!(%{
        id: :devsup_standin,
        start:
          {Supervisor, :start_link,
           [[child], [strategy: :one_for_one, name: PhoenixAssets.DevSupervisor]]}
      })

      :ok
    end

    test "status/1 reports a running child" do
      assert DevServer.status(:dummy) == :running
      assert DevServer.status(:missing) == :unknown
    end

    test "restart/1 terminates then restarts the child" do
      assert {:ok, pid} = DevServer.restart(:dummy)
      assert is_pid(pid)
      assert DevServer.status(:dummy) == :running
    end

    test "stop/1 terminates the child and status becomes :down" do
      assert DevServer.stop(:dummy) == :ok
      assert DevServer.status(:dummy) == :down
    end
  end
end

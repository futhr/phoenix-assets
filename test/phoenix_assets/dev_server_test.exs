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
  end

  test "log_line/2 is a no-op when no server is running" do
    refute Process.whereis(DevServer)
    assert DevServer.log_line("x", :vite) == :ok
  end

  test "status/1 is :unknown when the supervisor is absent" do
    assert DevServer.status(:vite) == :unknown
  end
end

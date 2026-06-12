defmodule PhoenixAssets.DevProcessTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.DevProcess

  test "to_child_spec/2 builds a telemetry-wrapped MuonTrap.Daemon spec" do
    process =
      DevProcess.new(
        id: :vite,
        command: ["pnpm", "vite", "--port", "5173"],
        cd: "assets",
        env: [{"NODE_ENV", "development"}]
      )

    spec =
      DevProcess.to_child_spec(process, logger_fun: {PhoenixAssets.DevServer, :log_line, [:vite]})

    assert spec.id == :vite
    assert spec.restart == :transient
    assert spec.shutdown == 500
    assert {DevProcess, :start_daemon, [:vite, command, args, opts]} = spec.start
    assert command == "pnpm"
    assert args == ["vite", "--port", "5173"]
    assert opts[:cd] == "assets"
    assert opts[:env] == [{"NODE_ENV", "development"}]
    assert opts[:logger_fun] == {PhoenixAssets.DevServer, :log_line, [:vite]}
    assert is_function(opts[:exit_status_to_reason], 1)
  end

  test "omits logger_fun when none is given" do
    process = DevProcess.new(id: :sb, command: ["pnpm", "storybook"], cd: "assets")

    {DevProcess, :start_daemon, [:sb, _, _, opts]} = DevProcess.to_child_spec(process).start

    refute Keyword.has_key?(opts, :logger_fun)
  end
end

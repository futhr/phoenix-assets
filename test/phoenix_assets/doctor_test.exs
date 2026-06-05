defmodule PhoenixAssets.DoctorTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context, Doctor}
  alias PhoenixAssets.Doctor.Check

  defmodule CrashPlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def doctor_checks(_, _) do
      [Check.new(id: :boom, run: fn _ -> raise "kaboom" end)]
    end
  end

  defp ctx(plugins \\ []) do
    tmp = Path.join(System.tmp_dir!(), "doc_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)
    config = Config.load!(otp_app: :my_app, asset_root: tmp, static_root: tmp)
    Context.new(config, env: :test, plugins: plugins)
  end

  test "passes in a non-production setup with a present asset root" do
    {status, _} = Doctor.run(ctx())
    assert status == :ok
  end

  test "errors in production when the manifest is missing" do
    {status, results} = Doctor.run(ctx(), production: true)

    assert status == :error

    assert Enum.any?(results, fn {check, r} ->
             check.id == :manifest_present and r.status == :error
           end)
  end

  test "production-only checks are skipped in non-production runs" do
    {_, results} = Doctor.run(ctx())
    refute Enum.any?(results, fn {check, _} -> check.id == :manifest_present end)
  end

  test "a crashing check is captured as an error, not propagated" do
    {status, results} = Doctor.run(ctx([{CrashPlugin, []}]))

    assert status == :error
    assert Enum.any?(results, fn {check, r} -> check.id == :boom and r.status == :error end)
  end
end

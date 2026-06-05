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

  defmodule StalePlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def generated_files(_, _) do
      [
        PhoenixAssets.GeneratedFile.new(
          path: "phoenix/never_written.ts",
          contents: "export const x = 1\n",
          plugin: :probe,
          kind: :probe
        )
      ]
    end
  end

  defmodule FailPlugin do
    @moduledoc false
    use PhoenixAssets.Plugin

    def init(_, _), do: {:error, :boom}
  end

  defp ctx(plugins \\ []) do
    tmp = Path.join(System.tmp_dir!(), "doc_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)
    config = Config.load!(otp_app: :my_app, asset_root: tmp, static_root: tmp)
    Context.new(config, env: :test, plugins: plugins)
  end

  defp result_for(results, id) do
    Enum.find_value(results, fn {check, r} -> if check.id == id, do: r end)
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

  test "errors when the asset root is missing" do
    config = Config.load!(otp_app: :my_app, asset_root: "/no/such/dir-#{System.unique_integer()}")
    {status, results} = Doctor.run(Context.new(config, env: :test))

    assert status == :error
    assert result_for(results, :asset_root).status == :error
  end

  test "passes the manifest check in production when the manifest is present" do
    context = ctx()
    path = Context.manifest_path(context)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, ~s({"src/app.ts":{"file":"assets/app.js"}}))

    {_status, results} = Doctor.run(context, production: true)
    assert result_for(results, :manifest_present).status == :ok
  end

  test "errors in production when generated contracts are stale" do
    {_status, results} = Doctor.run(ctx([{StalePlugin, []}]), production: true)
    assert result_for(results, :generated_fresh).status == :error
  end

  test "skips plugin checks when a plugin fails to initialise" do
    {_status, results} = Doctor.run(ctx([{FailPlugin, []}]))
    ids = Enum.map(results, fn {check, _} -> check.id end)

    assert :asset_root in ids
    refute :boom in ids
  end
end

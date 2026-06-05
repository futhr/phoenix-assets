defmodule PhoenixAssets.Doctor do
  @moduledoc """
  Runs configuration and production-readiness diagnostics.

  Collects the built-in core checks plus every plugin's `doctor_checks/2`, runs
  each against the context, and aggregates an overall status. A check tagged
  `production?: true` only runs under `run/2` with `production: true` (the CI/build
  path), where it can enforce things that are meaningless in development -- a
  present manifest, no stale generated contracts.

  A check that raises is captured and reported as an error rather than crashing
  the run.

  ## Why

  "It compiled" is not "it will serve correctly in production." The doctor turns
  the asset pipeline's invariants -- manifest present, contracts fresh, tooling
  installed -- into explicit, enforceable checks.
  """

  alias PhoenixAssets.{Context, Engine, Generated, Telemetry}
  alias PhoenixAssets.Doctor.Check

  @type result :: {Check.t(), Check.result()}

  @doc """
  Runs the diagnostics, returning `{status, results}`.

  `status` is `:ok` unless any check returned `:error`. With `production: true`,
  production-only checks are included.
  """
  @spec run(Context.t(), keyword()) :: {Check.status(), [result()]}
  def run(%Context{} = ctx, opts \\ []) do
    production? = Keyword.get(opts, :production, false)

    results =
      (builtin_checks() ++ plugin_checks(ctx))
      |> Enum.filter(&include?(&1, production?))
      |> Enum.map(fn check -> {check, safe_run(check, ctx)} end)

    status = if Enum.any?(results, fn {_, r} -> r.status == :error end), do: :error, else: :ok
    Telemetry.execute([:doctor, :run], %{checks: length(results)}, %{status: status})
    {status, results}
  end

  defp include?(%Check{production?: true}, production?), do: production?
  defp include?(_, _), do: true

  defp safe_run(%Check{run: run, id: id}, ctx) do
    run.(ctx)
  rescue
    exception -> Check.error("check #{id} crashed: #{Exception.message(exception)}")
  end

  defp plugin_checks(ctx) do
    case Engine.init_plugins(ctx) do
      {:ok, initialized} -> Engine.collect(ctx, initialized, :doctor_checks)
      {:error, _} -> []
    end
  end

  defp builtin_checks do
    [
      Check.new(id: :asset_root, group: :paths, run: &asset_root_check/1),
      Check.new(id: :package_manager, group: :tooling, run: &package_manager_check/1),
      Check.new(
        id: :generated_fresh,
        group: :generated,
        production?: true,
        run: &generated_check/1
      ),
      Check.new(id: :manifest_present, group: :build, production?: true, run: &manifest_check/1)
    ]
  end

  defp asset_root_check(ctx) do
    if File.dir?(ctx.asset_root) do
      Check.ok("asset root #{ctx.asset_root} exists")
    else
      Check.error("asset root #{ctx.asset_root} is missing", "create it or set :asset_root")
    end
  end

  defp package_manager_check(ctx) do
    manager = to_string(ctx.package_manager)

    if System.find_executable(manager) do
      Check.ok("#{manager} is available")
    else
      Check.warn("#{manager} was not found on PATH", "install #{manager}")
    end
  end

  defp generated_check(ctx) do
    if Generated.stale?(ctx) do
      Check.error("generated contracts are stale", "run mix phoenix_assets.gen")
    else
      Check.ok("generated contracts are up to date")
    end
  end

  defp manifest_check(ctx) do
    path = Context.manifest_path(ctx)

    if File.exists?(path) do
      Check.ok("Vite manifest is present")
    else
      Check.error("Vite manifest missing at #{path}", "run the production asset build")
    end
  end
end

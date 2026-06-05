defmodule PhoenixAssets.SvelteKit do
  @moduledoc """
  Integration plugin for SvelteKit (with Vite) under `phoenix_assets`.

  Contributes the supervised Vite dev process, the core endpoint-route and env
  contracts, and asset-graph page entries discovered from the SvelteKit routes
  directory. Page-route *authority* stays with SvelteKit -- this plugin only
  records which `+page.svelte` files exist so the graph can link them to Phoenix
  routes, shapes, and topics.

  ## Why

  Vite is the one dev process every Svelte app runs; supervising it (rather than
  leaving it to a shell watcher) is the baseline this plugin provides, plus the
  route/env contracts the frontend imports.
  """

  use PhoenixAssets.Plugin

  alias PhoenixAssets.{Context, DevProcess, Graph}
  alias PhoenixAssets.Doctor.Check
  alias PhoenixAssets.Generators.{Env, Routes}

  @default_vite_command ["pnpm", "vite", "--host", "127.0.0.1", "--port", "5173", "--strictPort"]
  @default_vite_port 5173

  @impl PhoenixAssets.Plugin
  def init(opts, _), do: {:ok, Map.new(opts)}

  @impl PhoenixAssets.Plugin
  def generated_files(ctx, _) do
    [Routes.generate(ctx), Env.generate(ctx)] |> Enum.reject(&is_nil/1)
  end

  @impl PhoenixAssets.Plugin
  def dev_processes(ctx, _) do
    vite = vite_opts(ctx)

    if Keyword.get(vite, :enabled, true) do
      [
        DevProcess.new(
          id: :vite,
          command: Keyword.get(vite, :command, @default_vite_command),
          cd: ctx.asset_root,
          port: Keyword.get(vite, :port, @default_vite_port)
        )
      ]
    else
      []
    end
  end

  @impl PhoenixAssets.Plugin
  def graph_entries(%Context{} = ctx, _) do
    routes_dir = Path.join([ctx.asset_root, "src", "routes"])

    if File.dir?(routes_dir) do
      routes_dir
      |> Path.join("**/+page.svelte")
      |> Path.wildcard()
      |> Enum.map(&page_entry(ctx, routes_dir, &1))
    else
      []
    end
  end

  @impl PhoenixAssets.Plugin
  def doctor_checks(_, _) do
    [
      Check.new(
        id: :svelte_config,
        group: :sveltekit,
        run: &file_check(&1, "svelte.config.js", "SvelteKit config")
      ),
      Check.new(
        id: :package_json,
        group: :sveltekit,
        run: &file_check(&1, "package.json", "package.json")
      )
    ]
  end

  defp vite_opts(ctx), do: ctx.config.dev[:vite] || []

  defp page_entry(ctx, routes_dir, file) do
    relative = Path.relative_to(file, routes_dir)
    route = relative |> Path.dirname() |> sveltekit_route()

    Graph.Entry.new(
      kind: :page,
      key: page_key(route),
      data: %{"route" => route},
      source: Path.relative_to(file, ctx.asset_root)
    )
  end

  defp sveltekit_route("."), do: "/"

  defp sveltekit_route(dir) do
    segments =
      dir
      |> String.split("/")
      |> Enum.reject(&route_group?/1)
      |> Enum.map(&segment_to_route/1)

    "/" <> Enum.join(segments, "/")
  end

  defp route_group?(segment),
    do: String.starts_with?(segment, "(") and String.ends_with?(segment, ")")

  defp segment_to_route("[" <> rest), do: ":" <> String.trim_trailing(rest, "]")
  defp segment_to_route(segment), do: segment

  defp page_key("/"), do: "Index"

  defp page_key(route) do
    route
    |> String.split("/")
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, ":")))
    |> Enum.map_join("", &Macro.camelize/1)
    |> case do
      "" -> "Index"
      key -> key
    end
  end

  defp file_check(ctx, file, label) do
    path = Path.join(ctx.asset_root, file)

    if File.exists?(path) do
      Check.ok("#{label} present")
    else
      Check.warn("#{label} missing at #{path}")
    end
  end
end

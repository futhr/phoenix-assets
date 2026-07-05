defmodule PhoenixAssets.Generators.Routes do
  @moduledoc """
  Generates typed Phoenix *endpoint* helpers from the router.

  Emits `routes.ts` -- typed builders for the server endpoints the frontend
  calls directly. Which routes qualify is governed by the configured path
  prefixes (default `/shapes` and `/api`):

      config :phoenix_assets,
        endpoint_prefixes: ["/api", "/shapes", "/webhooks"]

  It deliberately does **not** generate page routes: in a SvelteKit app the
  page-route authority is the frontend, so only the Phoenix-owned endpoints
  belong in a generated contract.

  Each route becomes a function keyed by its controller action (or route
  helper), taking its path parameters and returning the URL with parameters
  URL-encoded. When two routes share an action name, the later one is
  qualified with its controller (`articleIndex`); a numeric suffix is the
  last resort. Output is sorted by name for deterministic diffs.

  ## Example output

      export const routes = {
        articleBySlug: (slug: string | number) =>
          `/shapes/articles/${encodeURIComponent(String(slug))}`,
        health: () => "/api/health",
        publicArticles: () => "/shapes/articles",
      } as const

  ## Why

  Apps hand-build these URLs as string literals scattered across the client
  (`createShapeUrl("/articles")`). Generating them from the router gives one
  typed source that can't drift from the actual routes.
  """

  alias PhoenixAssets.{Context, GeneratedFile}
  alias PhoenixAssets.Generators.TS

  @doc """
  Generates the `routes.ts` contract, or `nil` when no router is configured.
  """
  @spec generate(Context.t()) :: GeneratedFile.t() | nil
  def generate(%Context{router: nil}), do: nil

  def generate(%Context{router: router} = ctx) do
    prefixes = ctx.config.endpoint_prefixes

    routes =
      router
      |> Phoenix.Router.routes()
      |> Enum.filter(&endpoint_route?(&1, prefixes))
      |> Enum.map(&entry/1)
      |> Enum.uniq_by(&{&1.name, &1.path})
      |> dedupe_names()
      |> Enum.sort_by(& &1.name)

    GeneratedFile.new(
      path: Path.join(ctx.generated_dir, "routes.ts"),
      contents: render(routes),
      plugin: :routes,
      kind: :routes
    )
  end

  defp endpoint_route?(%{path: path}, prefixes) do
    Enum.any?(prefixes, &String.starts_with?(path, &1))
  end

  defp entry(route) do
    %{
      name: name_for(route),
      controller: controller_name(route),
      path: route.path,
      params: TS.path_params(route.path)
    }
  end

  defp name_for(%{plug_opts: action}) when is_atom(action) and not is_nil(action),
    do: TS.camelize(action)

  defp name_for(%{helper: helper}) when is_binary(helper), do: TS.camelize(helper)
  defp name_for(%{path: path}), do: path |> path_slug() |> TS.camelize()

  defp controller_name(%{plug: plug}) when is_atom(plug) do
    case Atom.to_string(plug) do
      "Elixir." <> _ ->
        plug
        |> Module.split()
        |> List.last()
        |> String.replace_suffix("Controller", "")
        |> case do
          "" -> nil
          name -> Macro.underscore(name)
        end

      _ ->
        nil
    end
  end

  defp controller_name(_), do: nil

  defp path_slug(path) do
    path
    |> String.split("/")
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, ":") or String.starts_with?(&1, "*")))
    |> Enum.join("_")
  end

  defp dedupe_names(entries) do
    {result, _} =
      Enum.map_reduce(entries, MapSet.new(), fn entry, taken ->
        name = resolve_name(entry, taken)
        {%{entry | name: name}, MapSet.put(taken, name)}
      end)

    result
  end

  # The first route keeps the plain action name. A collision prefers the
  # controller-qualified form (`articleIndex`); only when that is also taken
  # does a numeric suffix apply. Resolution order is router declaration order,
  # so the result is deterministic and a rename can never collide with an
  # existing or earlier-renamed name.
  defp resolve_name(%{name: base} = entry, taken) do
    qualified = qualified_name(entry)

    cond do
      not MapSet.member?(taken, base) -> base
      qualified != nil and not MapSet.member?(taken, qualified) -> qualified
      true -> numeric_name(qualified || base, taken)
    end
  end

  defp qualified_name(%{controller: nil}), do: nil

  defp qualified_name(%{controller: controller, name: base}) do
    TS.camelize(controller) <> TS.pascalize(base)
  end

  defp numeric_name(base, taken) do
    Stream.iterate(2, &(&1 + 1))
    |> Stream.map(&"#{base}#{&1}")
    |> Enum.find(&(not MapSet.member?(taken, &1)))
  end

  defp render(routes) do
    [
      TS.header(),
      "\nexport const routes = {\n",
      Enum.map(routes, &render_route/1),
      "} as const\n\nexport type RouteName =\n",
      render_names(routes),
      "\n"
    ]
  end

  defp render_route(%{name: name, path: path, params: []}) do
    "  #{TS.object_key(name)}: () => #{JSON.encode!(path)},\n"
  end

  defp render_route(%{name: name, path: path, params: params}) do
    args = Enum.map_join(TS.arg_names(params), ", ", &"#{&1}: string | number")
    "  #{TS.object_key(name)}: (#{args}) => `#{TS.url_template(path)}`,\n"
  end

  defp render_names([]), do: "  never"

  defp render_names(routes) do
    Enum.map_join(routes, "\n", fn %{name: name} -> "  | #{JSON.encode!(name)}" end)
  end
end

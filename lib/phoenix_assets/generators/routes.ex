defmodule PhoenixAssets.Generators.Routes do
  @moduledoc """
  Generates typed Phoenix *endpoint* helpers from the router.

  Emits `routes.ts` -- typed builders for the server endpoints the frontend calls
  directly: the sync-shape routes (`/shapes/...`) and the JSON API
  (`/api/...`). It deliberately does **not** generate page routes: in a SvelteKit
  app the page-route authority is the frontend, so only the Phoenix-owned
  endpoints belong in a generated contract.

  Each route becomes a function keyed by its controller action (or route helper),
  taking its path parameters and returning the URL with parameters
  URL-encoded. Output is sorted by name for deterministic diffs.

  ## Example output

      export const routes = {
        health: () => "/api/health",
        portfolioBySlug: (slug: string | number) =>
          `/shapes/portfolios/${encodeURIComponent(String(slug))}`,
        publicPortfolios: () => "/shapes/portfolios",
      } as const

  ## Why

  Apps hand-build these URLs as string literals scattered across the client
  (`createShapeUrl("/portfolios")`). Generating them from the router gives one
  typed source that can't drift from the actual routes.
  """

  alias PhoenixAssets.{Context, GeneratedFile}
  alias PhoenixAssets.Generators.TS

  @endpoint_prefixes ["/shapes", "/api"]

  @doc """
  Generates the `routes.ts` contract, or `nil` when no router is configured.
  """
  @spec generate(Context.t()) :: GeneratedFile.t() | nil
  def generate(%Context{router: nil}), do: nil

  def generate(%Context{router: router} = ctx) do
    routes =
      router
      |> Phoenix.Router.routes()
      |> Enum.filter(&endpoint_route?/1)
      |> Enum.map(&entry/1)
      |> dedupe_names()
      |> Enum.sort_by(& &1.name)

    GeneratedFile.new(
      path: Path.join(ctx.generated_dir, "routes.ts"),
      contents: render(routes),
      plugin: :routes,
      kind: :routes
    )
  end

  defp endpoint_route?(%{path: path}) do
    Enum.any?(@endpoint_prefixes, &String.starts_with?(path, &1))
  end

  defp entry(route) do
    %{name: name_for(route), path: route.path, params: TS.path_params(route.path)}
  end

  defp name_for(%{plug_opts: action}) when is_atom(action) and not is_nil(action),
    do: TS.camelize(action)

  defp name_for(%{helper: helper}) when is_binary(helper), do: TS.camelize(helper)
  defp name_for(%{path: path}), do: path |> path_slug() |> TS.camelize()

  defp path_slug(path) do
    path
    |> String.split("/")
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, ":")))
    |> Enum.join("_")
  end

  defp dedupe_names(entries) do
    {result, _} =
      Enum.map_reduce(entries, %{}, fn entry, seen ->
        case Map.get(seen, entry.name, 0) do
          0 -> {entry, Map.put(seen, entry.name, 1)}
          n -> {%{entry | name: "#{entry.name}#{n + 1}"}, Map.put(seen, entry.name, n + 1)}
        end
      end)

    result
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
    |> IO.iodata_to_binary()
  end

  defp render_route(%{name: name, path: path, params: []}) do
    "  #{name}: () => #{Jason.encode!(path)},\n"
  end

  defp render_route(%{name: name, path: path, params: params}) do
    args = Enum.map_join(params, ", ", &"#{TS.camelize(&1)}: string | number")
    "  #{name}: (#{args}) => `#{TS.url_template(path)}`,\n"
  end

  defp render_names([]), do: "  never"

  defp render_names(routes) do
    Enum.map_join(routes, "\n", fn %{name: name} -> "  | #{Jason.encode!(name)}" end)
  end
end

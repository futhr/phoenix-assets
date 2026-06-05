defmodule PhoenixAssets.Electric do
  @moduledoc """
  Integration plugin that generates a typed ElectricSQL client from declarations.

  Reads the shapes declared in the module passed as `shapes:` (see
  `PhoenixAssets.Electric.Shapes`) and emits `electric.ts` -- a `ShapeStream`
  factory per shape, typed by the shape's row type and keyed by its parameters,
  with the URL built from the declared route. Also contributes graph entries and
  a doctor check per shape that the route exists in the router.

  ## Why

  This is where shape declarations become the client contract the frontend
  imports (`import { shapes } from "$phoenix/electric"`), generated from one
  source so URLs and row types cannot drift from the backend.
  """

  use PhoenixAssets.Plugin

  alias PhoenixAssets.Doctor.Check
  alias PhoenixAssets.GeneratedFile
  alias PhoenixAssets.Generators.TS
  alias PhoenixAssets.Graph

  @impl PhoenixAssets.Plugin
  def init(opts, ctx), do: {:ok, %{module: opts[:shapes] || ctx.config.stack[:shapes]}}

  @impl PhoenixAssets.Plugin
  def generated_files(_, %{module: nil}), do: []

  def generated_files(ctx, %{module: module}) do
    [
      GeneratedFile.new(
        path: Path.join(ctx.generated_dir, "electric.ts"),
        contents: render(shapes(module)),
        plugin: :electric,
        kind: :electric
      )
    ]
  end

  @impl PhoenixAssets.Plugin
  def graph_entries(_, %{module: nil}), do: []

  def graph_entries(_, %{module: module}) do
    Enum.map(shapes(module), fn {name, opts} ->
      Graph.Entry.new(
        kind: :electric_shape,
        key: to_string(name),
        data: %{"route" => opts[:route], "type" => TS.type_name(opts[:type])}
      )
    end)
  end

  @impl PhoenixAssets.Plugin
  def doctor_checks(_, %{module: nil}), do: []

  def doctor_checks(_, %{module: module}) do
    Enum.map(shapes(module), fn {name, opts} ->
      Check.new(
        id: :electric_shape,
        group: :electric,
        run: &route_check(&1, name, opts[:route])
      )
    end)
  end

  defp shapes(module), do: module.__phoenix_assets_shapes__()

  defp render(shapes) do
    sorted = Enum.sort_by(shapes, fn {name, _} -> to_string(name) end)

    types =
      sorted
      |> Enum.map(fn {_, opts} -> TS.type_name(opts[:type]) end)
      |> Enum.uniq()
      |> Enum.sort()

    [
      TS.header(),
      ~s|\nimport { ShapeStream } from "@electric-sql/client"\n|,
      import_types(types),
      "\nexport const shapes = {\n",
      Enum.map(sorted, &render_shape/1),
      "} as const\n"
    ]
    |> IO.iodata_to_binary()
  end

  defp import_types([]), do: ""

  defp import_types(types),
    do: ~s|import type { #{Enum.join(types, ", ")} } from "$phoenix/types"\n|

  defp render_shape({name, opts}) do
    route = opts[:route]
    type = TS.type_name(opts[:type])
    fname = TS.camelize(name)

    case TS.path_params(route) do
      [] ->
        "  #{fname}: () => new ShapeStream<#{type}>({ url: #{Jason.encode!(route)} }),\n"

      params ->
        args = Enum.map_join(params, ", ", &"#{TS.camelize(&1)}: string | number")

        "  #{fname}: (#{args}) => new ShapeStream<#{type}>({ url: `#{TS.url_template(route)}` }),\n"
    end
  end

  defp route_check(_, name, nil), do: Check.error("electric shape #{name} has no :route")

  defp route_check(%{router: nil}, name, route) do
    Check.warn("cannot validate route for shape #{name}: no router configured (#{route})")
  end

  defp route_check(%{router: router}, name, route) do
    if Enum.any?(Phoenix.Router.routes(router), &(&1.path == route)) do
      Check.ok("electric shape #{name} -> #{route}")
    else
      Check.error(
        "electric shape #{name} route #{route} is not in the router",
        "add the shape route"
      )
    end
  end
end

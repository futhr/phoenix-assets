defmodule PhoenixAssets.Types.Walker do
  @moduledoc """
  Walks Ash resources and renders TypeScript row types.

  Given the declarations from `PhoenixAssets.Types.Schema`, this resolves each
  resource's exposed fields (public attributes by default, minus sensitive ones,
  adjusted by `:omit`/`:expose`, plus whitelisted calculations) and maps each Ash
  type to TypeScript. The exposure model is deterministic -- it never tries to
  evaluate Ash field policies (which are dynamic); instead `PhoenixAssets.Types`
  cross-checks exposed fields against declared field policies and warns.

  ## Type mapping highlights

    * `uuid`, `ci_string`, datetimes, `decimal`, `binary` -> `string`
    * `integer`, `float` -> `number`
    * `atom` with `one_of` -> a string-literal union
    * `{:array, t}` -> `Array<t>`; `map` with `:fields` -> a typed object
    * nullable attributes gain `| null`

  ## Why

  Hand-maintaining dozens of row types against evolving Ash resources is the
  single biggest source of frontend/backend drift. Deriving them -- faithfully,
  with sensitive fields excluded by construction -- removes that whole class of bug.
  """

  alias Ash.Resource.Info
  alias Ash.Type
  alias Ash.Type.NewType
  alias PhoenixAssets.Generators.TS

  @scalar %{
    uuid: "string",
    uuid_v7: "string",
    string: "string",
    ci_string: "string",
    binary: "string",
    url_encoded_binary: "string",
    date: "string",
    time: "string",
    time_usec: "string",
    utc_datetime: "string",
    utc_datetime_usec: "string",
    naive_datetime: "string",
    decimal: "string",
    integer: "number",
    float: "number",
    boolean: "boolean",
    keyword: "Record<string, unknown>",
    vector: "number[]"
  }

  @doc "Renders the full `types.ts` body from the declared types."
  @spec render([{String.t() | atom(), keyword()}]) :: binary()
  def render(type_decls) do
    blocks =
      type_decls
      |> Enum.sort_by(fn {name, _} -> TS.type_name(name) end)
      |> Enum.map(&render_type/1)

    [TS.header(), "\n", blocks] |> IO.iodata_to_binary()
  end

  @doc """
  Resolves the exposed `{field_name, ts_type}` pairs for a resource declaration.

  Public so `PhoenixAssets.Types` can cross-check the exposed field set against
  the resource's field policies.
  """
  @spec fields(module(), keyword()) :: [{atom(), String.t()}]
  def fields(resource, opts) do
    base =
      resource |> select_attributes(opts) |> Enum.map(fn attr -> {attr.name, attr_ts(attr)} end)

    exposed =
      opts
      |> Keyword.get(:expose, [])
      |> Enum.map(fn name -> {name, attr_ts(Info.attribute(resource, name))} end)

    calcs =
      opts
      |> Keyword.get(:calculations, [])
      |> Enum.map(fn name -> {name, calc_ts(Info.calculation(resource, name))} end)

    (base ++ exposed ++ calcs)
    |> Enum.uniq_by(fn {name, _} -> name end)
    |> Enum.sort_by(fn {name, _} -> to_string(name) end)
  end

  defp render_type({name, opts}) do
    resource = Keyword.fetch!(opts, :resource)

    body =
      resource
      |> fields(opts)
      |> Enum.map_join("\n", fn {field, ts} -> "  #{field}: #{ts}" end)

    "export type #{TS.type_name(name)} = {\n#{body}\n}\n\n"
  end

  defp select_attributes(resource, opts) do
    omit = Keyword.get(opts, :omit, [])

    resource
    |> attributes(Keyword.get(opts, :only, :public))
    |> Enum.reject(fn attr -> attr.sensitive? or attr.name in omit end)
  end

  defp attributes(resource, :all), do: Info.attributes(resource)
  defp attributes(resource, _), do: Info.public_attributes(resource)

  defp attr_ts(%{type: type, allow_nil?: nilable, constraints: constraints}) do
    base = map_type(type, constraints || [])
    if nilable, do: base <> " | null", else: base
  end

  defp calc_ts(%{type: type} = calc), do: map_type(type, Map.get(calc, :constraints) || [])
  defp calc_ts(_), do: "unknown"

  defp map_type({:array, inner}, constraints) do
    "Array<#{map_type(inner, Keyword.get(constraints, :items, []))}>"
  end

  defp map_type(type, constraints) when is_atom(type) do
    cond do
      type == Type.Union -> union_type(constraints)
      short = short_name(type) -> map_short(short, constraints)
      NewType.new_type?(type) -> map_type(NewType.subtype_of(type), constraints)
      Info.resource?(type) -> embedded_type(type)
      true -> "unknown"
    end
  end

  defp map_type(_, _), do: "unknown"

  defp union_type(constraints) do
    case Keyword.get(constraints, :types) do
      nil ->
        "unknown"

      types ->
        types
        |> Enum.map(fn {_, config} -> map_type(config[:type], config[:constraints] || []) end)
        |> Enum.uniq()
        |> Enum.join(" | ")
    end
  end

  defp embedded_type(resource) do
    body =
      resource
      |> Info.public_attributes()
      |> Enum.reject(& &1.sensitive?)
      |> Enum.sort_by(& &1.name)
      |> Enum.map_join("; ", fn attr -> "#{attr.name}: #{attr_ts(attr)}" end)

    "{ " <> body <> " }"
  end

  defp map_short(:atom, constraints), do: atom_type(constraints)
  defp map_short(:map, constraints), do: map_object(constraints)
  defp map_short(short, _), do: Map.get(@scalar, short, "unknown")

  defp atom_type(constraints) do
    case Keyword.get(constraints, :one_of) do
      nil -> "string"
      values -> TS.string_union(values)
    end
  end

  defp map_object(constraints) do
    case Keyword.get(constraints, :fields) do
      nil ->
        "Record<string, unknown>"

      fields ->
        body =
          Enum.map_join(fields, "; ", fn {name, field_opts} ->
            "#{name}: #{map_type(field_opts[:type], field_opts[:constraints] || [])}"
          end)

        "{ " <> body <> " }"
    end
  end

  # `type` may be a builtin module (`Ash.Type.String`, as stored on attributes)
  # or already a short atom (`:string`, as stored inside union/map constraints).
  defp short_name(type) when type in [:atom, :map] or is_map_key(@scalar, type), do: type

  defp short_name(type) do
    Enum.find_value(Type.short_names(), fn
      {short, ^type} -> short
      _ -> nil
    end)
  end
end

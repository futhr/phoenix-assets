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
    * `atom` with `one_of`, or an `Ash.Type.Enum` module -> a string-literal union
    * `{:array, t}` -> `Array<t>`; `map` with `:fields` -> a typed object
    * nullable attributes gain `| null`
    * embedded resources are inlined structurally; a cyclic embedding renders
      as `unknown` at the point of recursion (defense in depth -- current Ash
      rejects declared type cycles at compile time)

  Unknown names in `:expose` or `:calculations` raise an `ArgumentError`
  naming the resource and the field, rather than emitting a silently wrong
  contract.

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
    ancestors = MapSet.new([resource])

    base =
      resource
      |> select_attributes(opts)
      |> Enum.map(fn attr -> {attr.name, attr_ts(attr, ancestors)} end)

    exposed =
      opts
      |> Keyword.get(:expose, [])
      |> Enum.map(fn name ->
        attr = Info.attribute(resource, name) || unknown_field!(resource, :expose, name)
        {name, attr_ts(attr, ancestors)}
      end)

    calcs =
      opts
      |> Keyword.get(:calculations, [])
      |> Enum.map(fn name ->
        calc = Info.calculation(resource, name) || unknown_field!(resource, :calculations, name)
        {name, calc_ts(calc, ancestors)}
      end)

    (base ++ exposed ++ calcs)
    |> Enum.uniq_by(fn {name, _} -> name end)
    |> Enum.sort_by(fn {name, _} -> to_string(name) end)
  end

  @spec unknown_field!(module(), atom(), atom()) :: no_return()
  defp unknown_field!(resource, option, name) do
    raise ArgumentError,
          "phoenix_assets: unknown #{option_noun(option)} #{inspect(name)} in " <>
            "#{inspect(option)} for #{inspect(resource)}"
  end

  defp option_noun(:expose), do: "attribute"
  defp option_noun(:calculations), do: "calculation"

  defp render_type({name, opts}) do
    resource = Keyword.fetch!(opts, :resource)

    body =
      resource
      |> fields(opts)
      |> Enum.map_join("\n", fn {field, ts} -> "  #{TS.object_key(field)}: #{ts}" end)

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

  defp attr_ts(%{type: type, allow_nil?: nilable, constraints: constraints}, ancestors) do
    base = map_type(type, constraints || [], ancestors)
    if nilable, do: base <> " | null", else: base
  end

  defp calc_ts(calc, ancestors) do
    map_type(calc.type, calc.constraints || [], ancestors)
  end

  defp map_type({:array, inner}, constraints, ancestors) do
    "Array<#{map_type(inner, Keyword.get(constraints, :items, []), ancestors)}>"
  end

  defp map_type(type, constraints, ancestors) when is_atom(type) do
    cond do
      type == Type.Union -> union_type(constraints, ancestors)
      short = short_name(type) -> map_short(short, constraints, ancestors)
      values = enum_values(type) -> TS.string_union(values)
      NewType.new_type?(type) -> map_type(NewType.subtype_of(type), constraints, ancestors)
      Info.resource?(type) -> embedded_type(type, ancestors)
      true -> "unknown"
    end
  end

  defp map_type(_, _, _), do: "unknown"

  # `Ash.Type.Enum` modules carry their members in `values/0`; render them as a
  # string-literal union ("active" | "inactive") instead of falling through to
  # `unknown`. Inline `:atom` attributes with `one_of` go through `atom_type/1`.
  defp enum_values(type) do
    if Code.ensure_loaded?(type) and function_exported?(type, :values, 0) and
         Ash.Type.ash_type?(type) do
      type.values()
    end
  end

  defp union_type(constraints, ancestors) do
    case Keyword.get(constraints, :types) do
      nil ->
        "unknown"

      types ->
        types
        |> Enum.map(fn {_, config} ->
          map_type(config[:type], config[:constraints] || [], ancestors)
        end)
        |> Enum.uniq()
        |> Enum.join(" | ")
    end
  end

  # `ancestors` is the chain of resources currently being inlined; meeting one
  # again is a cycle, which renders as `unknown` instead of recursing forever.
  # Re-use of the same embedded resource on sibling branches stays inlined.
  defp embedded_type(resource, ancestors) do
    if MapSet.member?(ancestors, resource) do
      "unknown"
    else
      ancestors = MapSet.put(ancestors, resource)

      body =
        resource
        |> Info.public_attributes()
        |> Enum.reject(& &1.sensitive?)
        |> Enum.sort_by(& &1.name)
        |> Enum.map_join("; ", fn attr ->
          "#{TS.object_key(attr.name)}: #{attr_ts(attr, ancestors)}"
        end)

      "{ " <> body <> " }"
    end
  end

  defp map_short(:atom, constraints, _), do: atom_type(constraints)
  defp map_short(:map, constraints, ancestors), do: map_object(constraints, ancestors)
  defp map_short(short, _, _), do: Map.get(@scalar, short, "unknown")

  defp atom_type(constraints) do
    case Keyword.get(constraints, :one_of) do
      nil -> "string"
      values -> TS.string_union(values)
    end
  end

  defp map_object(constraints, ancestors) do
    case Keyword.get(constraints, :fields) do
      nil ->
        "Record<string, unknown>"

      fields ->
        body =
          Enum.map_join(fields, "; ", fn {name, field_opts} ->
            type = map_type(field_opts[:type], field_opts[:constraints] || [], ancestors)
            "#{TS.object_key(name)}: #{type}"
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

defmodule PhoenixAssets.Electric.Shapes do
  @moduledoc """
  DSL for declaring ElectricSQL shapes that drive generated TypeScript clients.

  A host module `use`s this and declares each shape with the Phoenix endpoint
  that serves it and the row type it yields:

      defmodule MyApp.Assets.ElectricShapes do
        use PhoenixAssets.Electric.Shapes

        shape :public_articles, route: "/shapes/articles", type: "ArticleRow"
        shape :user_articles,
          route: "/shapes/users/:user_id/articles",
          type: "ArticleRow",
          params: [:user_id]
      end

  Declarations are validated at compile time: a missing `route:`/`type:`, an
  unknown option, a glob (`*`) segment, or a `params:` list that does not match
  the route's `:placeholders` is a compile error. `params:` is optional documentation of
  the route's placeholders; the generated factory always derives its parameters
  from the route itself.

  The declarations are metadata only -- the server side (running the query
  through `sync_render/3`) stays in the host's controller, exactly where its
  policies and tenancy already live. This DSL exists so the *client* contract
  can be generated from one place and validated against the router.

  > #### `use PhoenixAssets.Electric.Shapes` {: .info}
  >
  > Using this module imports `shape/2` and defines
  > `__phoenix_assets_shapes__/0` with the validated declarations.

  """

  alias PhoenixAssets.Generators.TS

  @shape_schema NimbleOptions.new!(
                  route: [
                    type: :string,
                    required: true,
                    doc: "the Phoenix route serving the shape (`:placeholders` allowed)"
                  ],
                  type: [
                    type: {:or, [:string, :atom]},
                    required: true,
                    doc: "the TypeScript row type the shape yields"
                  ],
                  params: [
                    type: {:list, :atom},
                    doc: "optional; must exactly match the route's `:placeholders`"
                  ]
                )

  @doc false
  defmacro __using__(_) do
    quote do
      import PhoenixAssets.Electric.Shapes, only: [shape: 2]
      Module.register_attribute(__MODULE__, :phoenix_assets_shapes, accumulate: true)
      @before_compile PhoenixAssets.Electric.Shapes
    end
  end

  @doc "Declares an Electric shape: `route:`, `type:`, and optional `params:`."
  defmacro shape(name, opts) do
    quote do
      @phoenix_assets_shapes {unquote(name), unquote(opts)}
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    shapes =
      env.module
      |> Module.get_attribute(:phoenix_assets_shapes)
      |> List.wrap()
      |> Enum.reverse()
      |> Enum.map(fn {name, opts} -> {name, validate!(env, name, opts)} end)

    ensure_unique_names!(env, shapes)

    quote do
      @doc "Returns the declared Electric shapes as `{name, opts}` pairs."
      def __phoenix_assets_shapes__, do: unquote(Macro.escape(shapes))
    end
  end

  defp ensure_unique_names!(env, shapes) do
    names = Enum.map(shapes, fn {name, _} -> name end)

    case names -- Enum.uniq(names) do
      [] -> :ok
      [dup | _] -> compile_error!(env, dup, "declared more than once")
    end
  end

  defp validate!(env, name, opts) do
    opts =
      case NimbleOptions.validate(opts, @shape_schema) do
        {:ok, validated} -> validated
        {:error, error} -> compile_error!(env, name, Exception.message(error))
      end

    route = opts[:route]
    _ = TS.type_name(opts[:type])

    if route |> String.split("/") |> Enum.any?(&String.starts_with?(&1, "*")) do
      compile_error!(env, name, "glob segments (#{route}) are not supported in shape routes")
    end

    placeholders = route |> TS.path_params() |> Enum.sort()
    declared = opts |> Keyword.get(:params, []) |> Enum.map(&to_string/1) |> Enum.sort()

    if Keyword.has_key?(opts, :params) and declared != placeholders do
      compile_error!(
        env,
        name,
        "params #{inspect(declared)} do not match the route's placeholders " <>
          "#{inspect(placeholders)} (#{route})"
      )
    end

    opts
  rescue
    error in ArgumentError -> compile_error!(env, name, Exception.message(error))
  end

  @spec compile_error!(Macro.Env.t(), term(), String.t()) :: no_return()
  defp compile_error!(env, name, message),
    do: PhoenixAssets.DSL.compile_error!(env, "shape", name, message)
end

defmodule PhoenixAssets.Electric.Shapes do
  @moduledoc """
  DSL for declaring ElectricSQL shapes that drive generated TypeScript clients.

  A host module `use`s this and declares each shape with the Phoenix endpoint
  that serves it, the row type it yields, and its parameters:

      defmodule MyApp.Assets.ElectricShapes do
        use PhoenixAssets.Electric.Shapes

        shape :public_portfolios, route: "/shapes/portfolios", type: "PortfolioRow"
        shape :user_portfolios,
          route: "/shapes/users/:user_id/portfolios",
          type: "PortfolioRow",
          params: [:user_id]
      end

  The declarations are metadata only -- the server side (running the Ash query
  through `sync_render/3`) stays in the host's controller, exactly where its
  policies and tenancy already live. This DSL exists so the *client* contract can
  be generated from one place and validated against the router.

  ## Why

  Hand-built `createShapeUrl("/portfolios")` strings and hand-written row types
  drift from the backend. Declaring the shape once lets `PhoenixAssets.Electric`
  generate a typed `ShapeStream` factory and the doctor confirm the route exists.
  """

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
      env.module |> Module.get_attribute(:phoenix_assets_shapes) |> List.wrap() |> Enum.reverse()

    quote do
      @doc "Returns the declared Electric shapes as `{name, opts}` pairs."
      def __phoenix_assets_shapes__, do: unquote(Macro.escape(shapes))
    end
  end
end

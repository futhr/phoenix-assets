defmodule PhoenixAssets.Types.Schema do
  @moduledoc """
  DSL for declaring which Ash resources become generated TypeScript row types.

  A host module `use`s this and declares each type:

      defmodule MyApp.Assets.Types do
        use PhoenixAssets.Types.Schema

        type "PortfolioRow",
          resource: MyApp.Portfolio.Portfolio,
          only: :public,
          omit: [:internal_score],
          calculations: [:like_count]
      end

  Options per `type/2`:

    * `:resource` (required) -- the Ash resource module.
    * `:only` -- `:public` (default) or `:all`.
    * `:omit` -- attribute names to drop even if otherwise included.
    * `:expose` -- non-public attribute names to add (opt-in escape hatch).
    * `:calculations` -- calculation names to include.

  ## Why

  Field exposure is a deliberate, auditable decision (sensitive fields must stay
  out of wire rows). Declaring it explicitly -- rather than reflecting every
  attribute -- keeps the generated types faithful to what the API actually serves.
  """

  @doc false
  defmacro __using__(_) do
    quote do
      import PhoenixAssets.Types.Schema, only: [type: 2]
      Module.register_attribute(__MODULE__, :phoenix_assets_types, accumulate: true)
      @before_compile PhoenixAssets.Types.Schema
    end
  end

  @doc "Declares a generated TypeScript type from an Ash resource."
  defmacro type(name, opts) do
    quote do
      @phoenix_assets_types {unquote(name), unquote(opts)}
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    types =
      env.module |> Module.get_attribute(:phoenix_assets_types) |> List.wrap() |> Enum.reverse()

    quote do
      @doc "Returns the declared types as `{name, opts}` pairs."
      def __phoenix_assets_types__, do: unquote(Macro.escape(types))
    end
  end
end

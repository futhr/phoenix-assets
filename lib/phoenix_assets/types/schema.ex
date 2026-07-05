defmodule PhoenixAssets.Types.Schema do
  @moduledoc """
  DSL for declaring which Ash resources become generated TypeScript row types.

  A host module `use`s this and declares each type:

      defmodule MyApp.Assets.Types do
        use PhoenixAssets.Types.Schema

        type "ArticleRow",
          resource: MyApp.Content.Article,
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

  Declarations are validated at compile time: a missing `:resource` or an
  unknown option is a compile error. Field-level names (`:expose`,
  `:calculations`) are checked at generation time against the resource, which
  raises a clear error for unknown names.

  ## Why

  Field exposure is a deliberate, auditable decision (sensitive fields must stay
  out of wire rows). Declaring it explicitly -- rather than reflecting every
  attribute -- keeps the generated types faithful to what the API actually serves.
  """

  @type_schema NimbleOptions.new!(
                 resource: [type: :atom, required: true, doc: "the Ash resource module"],
                 only: [type: {:in, [:public, :all]}, default: :public],
                 omit: [type: {:list, :atom}, default: []],
                 expose: [type: {:list, :atom}, default: []],
                 calculations: [type: {:list, :atom}, default: []]
               )

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
      env.module
      |> Module.get_attribute(:phoenix_assets_types)
      |> List.wrap()
      |> Enum.reverse()
      |> Enum.map(fn {name, opts} -> {name, validate!(env, name, opts)} end)

    ensure_unique_names!(env, types)

    quote do
      @doc "Returns the declared types as `{name, opts}` pairs."
      def __phoenix_assets_types__, do: unquote(Macro.escape(types))
    end
  end

  defp ensure_unique_names!(env, types) do
    names = Enum.map(types, fn {name, _} -> name end)

    case names -- Enum.uniq(names) do
      [] ->
        :ok

      [dup | _] ->
        compile_error!(env, dup, "declared more than once")
    end
  end

  defp validate!(env, name, opts) do
    case NimbleOptions.validate(opts, @type_schema) do
      {:ok, validated} ->
        validated

      {:error, error} ->
        compile_error!(env, name, Exception.message(error))
    end
  end

  @spec compile_error!(Macro.Env.t(), term(), String.t()) :: no_return()
  defp compile_error!(env, name, message),
    do: PhoenixAssets.DSL.compile_error!(env, "type", name, message)
end

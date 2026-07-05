defmodule PhoenixAssets.Types do
  @moduledoc """
  Integration plugin that generates TypeScript row types from Ash resources.

  Reads the type declarations from the module passed as `types:` (see
  `PhoenixAssets.Types.Schema`), runs them through `PhoenixAssets.Types.Walker`,
  and emits `types.ts`. Generation is skipped (with a doctor warning) when Ash is
  not loaded, so the stack package stays usable without it.

  ## The field-policy safety net

  Ash field policies are dynamic and cannot be evaluated at generation time, so
  the walker uses a deterministic exposure model (public attributes, sensitive
  excluded, `:omit`/`:expose` applied). To catch the data-leak class of mistake,
  this plugin adds a doctor check per type that *warns* when an exposed field also
  appears in one of the resource's field policies -- prompting a deliberate
  `:omit` decision.

  ## Why

  Generated row types are only safe if exposure is deliberate. Pairing a
  conservative default with a loud field-policy cross-check gives both
  productivity and a guardrail against leaking gated fields.
  """

  use PhoenixAssets.Plugin

  alias PhoenixAssets.Doctor.Check
  alias PhoenixAssets.GeneratedFile
  alias PhoenixAssets.Types.Walker

  @impl PhoenixAssets.Plugin
  def init(opts, ctx), do: {:ok, %{module: opts[:types] || ctx.config.stack[:types]}}

  @impl PhoenixAssets.Plugin
  def generated_files(_, %{module: nil}), do: []

  def generated_files(ctx, %{module: module}) do
    if ash_available?() do
      [
        GeneratedFile.new(
          path: Path.join(ctx.generated_dir, "types.ts"),
          contents: Walker.render(types(module)),
          plugin: :types,
          kind: :types
        )
      ]
    else
      []
    end
  end

  @impl PhoenixAssets.Plugin
  def doctor_checks(_, %{module: nil}), do: []

  def doctor_checks(_, %{module: module}) do
    if ash_available?() do
      Enum.map(types(module), fn {name, opts} ->
        Check.new(
          id: :types_field_policy,
          group: :types,
          run: fn _ -> field_policy_check(name, opts) end
        )
      end)
    else
      [
        Check.new(
          id: :ash_missing,
          group: :types,
          run: fn _ -> Check.warn("Ash is not loaded; TypeScript types were not generated") end
        )
      ]
    end
  end

  defp types(module), do: module.__phoenix_assets_types__()

  defp ash_available?, do: Code.ensure_loaded?(Ash.Resource.Info)

  defp field_policy_check(name, opts) do
    resource = Keyword.fetch!(opts, :resource)
    exposed = resource |> Walker.fields(opts) |> Enum.map(fn {field, _} -> field end)

    case field_policy_fields(resource) do
      {:ok, policy_fields} ->
        case Enum.filter(exposed, &(&1 in policy_fields)) do
          [] ->
            Check.ok("type #{name}: no exposed field has a field policy")

          fields ->
            Check.warn(
              "type #{name} exposes field-policy-gated fields: #{Enum.join(fields, ", ")}",
              "confirm these should be public, or add them to :omit"
            )
        end

      {:error, message} ->
        # The cross-check is a data-leak safety net; an introspection failure
        # must surface as a warning, not silently pass as "no policies".
        Check.warn(
          "type #{name}: could not inspect field policies (#{message})",
          "verify #{inspect(resource)}'s policies compile; the cross-check was skipped"
        )
    end
  rescue
    # Type names are host strings, not a bounded atom set, so the check id
    # cannot carry them; name the type in the message so a crash is traceable
    # to the offending declaration rather than the shared `:types_field_policy`.
    exception ->
      Check.error("type #{name} field-policy check crashed: #{Exception.message(exception)}")
  end

  defp field_policy_fields(resource) do
    if Code.ensure_loaded?(Ash.Policy.Info) and
         function_exported?(Ash.Policy.Info, :field_policies, 1) do
      fields =
        resource
        |> Ash.Policy.Info.field_policies()
        |> Enum.flat_map(fn policy -> List.wrap(policy.fields) end)
        |> Enum.uniq()

      {:ok, fields}
    else
      {:ok, []}
    end
  rescue
    exception -> {:error, Exception.message(exception)}
  end
end

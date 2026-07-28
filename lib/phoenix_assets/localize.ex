defmodule PhoenixAssets.Localize do
  @moduledoc """
  Integration plugin that generates the locale contract for the frontend.

  Emits `locales.ts` -- the `Locale` union, the `locales` tuple, and
  `defaultLocale` -- from either an explicit `locales:` list or, by default, the
  subdirectories of `priv/gettext` (override the scan root with `gettext_dir:`
  for umbrella or non-standard layouts), replacing a separate script that scans
  gettext directories and writes frontend locale data.

  `defaultLocale` resolves in order: the `default_locale:` option, the
  configured Gettext backend's default, then the first locale alphabetically.
  Declare one of the first two when the backend default is not the
  alphabetically-first locale -- with locales `de` and `en`, the bare fallback
  picks `de`.

  ## Configuring without a preset

  Every option here is also a `:stack` key, so a host that only wants to pin its
  market locales does not need to write a preset module:

      config :phoenix_assets, :stack,
        locales: ["sv", "en", "no", "da"],
        default_locale: "sv",
        gettext_backend: MyAppWeb.Gettext

  A preset's `integration/2` options win over the `:stack` config, so a preset
  can still override per-app defaults.

  """

  use PhoenixAssets.Plugin

  alias PhoenixAssets.{GeneratedFile, Graph}
  alias PhoenixAssets.Generators.TS

  @gettext_dir "priv/gettext"
  @stack_keys [:gettext_backend, :gettext_dir, :locales, :default_locale]

  @impl PhoenixAssets.Plugin
  def init(opts, ctx) do
    {:ok, Enum.reduce(@stack_keys, Map.new(opts), &put_stack_key(&1, &2, ctx))}
  end

  # A `:stack` key fills in only where the preset left off, and a key the host
  # never set stays absent rather than becoming nil -- that absence is what
  # separates "no locales declared" (scan priv/gettext) from "locales: []"
  # (a misconfiguration worth raising on).
  defp put_stack_key(key, state, ctx) do
    case ctx.config.stack[key] do
      nil -> state
      value -> Map.put_new(state, key, value)
    end
  end

  @impl PhoenixAssets.Plugin
  def generated_files(ctx, state) do
    locales = locales(state)
    default = default_locale(state, locales)
    validate_default!(state, locales, default)

    [
      GeneratedFile.new(
        path: Path.join(ctx.generated_dir, "locales.ts"),
        contents: render(locales, default),
        plugin: :localize,
        kind: :locales
      )
    ]
  end

  @impl PhoenixAssets.Plugin
  def graph_entries(_, state) do
    Enum.map(locales(state), fn locale ->
      Graph.Entry.new(kind: :locale, key: locale, data: %{})
    end)
  end

  defp locales(state) do
    case Map.get(state, :locales) do
      nil -> scan_gettext(Map.get(state, :gettext_dir, @gettext_dir))
      list -> Enum.map(list, &to_string/1)
    end
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp default_locale(state, locales) do
    resolved = Map.get(state, :default_locale) || backend_default(state) || List.first(locales)
    resolved && to_string(resolved)
  end

  # An explicit empty `locales:` list is a misconfiguration: it would emit a
  # `Locale = never` union, so refuse it and point at the fix. An *empty scan*
  # of `priv/gettext` is not an error -- a project that has not populated its
  # gettext tree yet still gets a valid (empty) contract instead of a crash.
  defp validate_default!(state, [], _) do
    if Map.has_key?(state, :locales) do
      raise ArgumentError,
            "phoenix_assets localize: no locales found; declare `locales:` or populate " <>
              "#{@gettext_dir}"
    end
  end

  defp validate_default!(_, locales, default) do
    unless default in locales do
      raise ArgumentError,
            "phoenix_assets localize: default locale #{inspect(default)} is not one of " <>
              "#{inspect(locales)}; set `default_locale:` (or the Gettext backend default) " <>
              "to a declared locale"
    end
  end

  # A Gettext backend knows its own default; preferring it keeps the generated
  # defaultLocale aligned with what the backend actually falls back to.
  defp backend_default(%{gettext_backend: backend}) when is_atom(backend) and backend != nil do
    if Code.ensure_loaded?(backend) and function_exported?(backend, :__gettext__, 1) do
      backend.__gettext__(:default_locale)
    end
  end

  defp backend_default(_), do: nil

  defp scan_gettext(dir) do
    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.filter(&(not String.starts_with?(&1, ".") and File.dir?(Path.join(dir, &1))))
    else
      []
    end
  end

  defp render(locales, default) do
    [
      TS.header(),
      "\nexport const locales = #{JSON.encode!(locales)} as const\n",
      "export type Locale = (typeof locales)[number]\n",
      render_default_locale(default)
    ]
    |> IO.iodata_to_binary()
  end

  defp render_default_locale(nil), do: "export const defaultLocale: Locale | null = null\n"

  defp render_default_locale(default),
    do: "export const defaultLocale: Locale = #{JSON.encode!(default)}\n"
end

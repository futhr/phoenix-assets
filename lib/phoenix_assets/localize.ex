defmodule PhoenixAssets.Localize do
  @moduledoc """
  Integration plugin that generates the locale contract for the frontend.

  Emits `locales.ts` -- the `Locale` union, the `locales` tuple, and
  `defaultLocale` -- from either an explicit `locales:` list or, by default, the
  subdirectories of `priv/gettext` (override the scan root with `gettext_dir:`
  for umbrella or non-standard layouts). This subsumes the common bespoke
  "scan gettext, write locales.json" build script.

  `defaultLocale` resolves in order: the `default_locale:` option, the
  configured Gettext backend's default (`gettext_backend:` option or
  `config :phoenix_assets, :stack, gettext_backend: MyApp.Gettext`), then the
  first locale alphabetically. Declare one of the first two when the backend
  default is not the alphabetically-first locale -- with locales `de` and `en`,
  the bare fallback picks `de`.

  ## Why

  The set of locales lives in `priv/gettext`; duplicating it in a hand-written
  frontend constant is exactly the kind of drift this library removes.
  """

  use PhoenixAssets.Plugin

  alias PhoenixAssets.{GeneratedFile, Graph}
  alias PhoenixAssets.Generators.TS

  @gettext_dir "priv/gettext"

  @impl PhoenixAssets.Plugin
  def init(opts, ctx) do
    state =
      opts
      |> Map.new()
      |> Map.put_new(:gettext_backend, ctx.config.stack[:gettext_backend])

    {:ok, state}
  end

  @impl PhoenixAssets.Plugin
  def generated_files(ctx, state) do
    locales = locales(state)
    default = default_locale(state, locales)

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
    Map.get(state, :default_locale) || backend_default(state) || List.first(locales) || "en"
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
      |> Enum.reject(&String.starts_with?(&1, "."))
      |> Enum.filter(&File.dir?(Path.join(dir, &1)))
    else
      []
    end
  end

  defp render(locales, default) do
    [
      TS.header(),
      "\nexport const locales = #{JSON.encode!(locales)} as const\n",
      "export type Locale = (typeof locales)[number]\n",
      "export const defaultLocale: Locale = #{JSON.encode!(default)}\n"
    ]
    |> IO.iodata_to_binary()
  end
end

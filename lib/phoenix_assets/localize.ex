defmodule PhoenixAssets.Localize do
  @moduledoc """
  Integration plugin that generates the locale contract for the frontend.

  Emits `locales.ts` -- the `Locale` union, the `locales` tuple, and
  `defaultLocale` -- from either an explicit `locales:` list or, by default, the
  subdirectories of `priv/gettext` (override the scan root with `gettext_dir:`
  for umbrella or non-standard layouts). This subsumes the common bespoke
  "scan gettext, write locales.json" build script.

  ## Why

  The set of locales lives in `priv/gettext`; duplicating it in a hand-written
  frontend constant is exactly the kind of drift this library removes.
  """

  use PhoenixAssets.Plugin

  alias PhoenixAssets.{GeneratedFile, Graph}
  alias PhoenixAssets.Generators.TS

  @gettext_dir "priv/gettext"

  @impl PhoenixAssets.Plugin
  def init(opts, _), do: {:ok, Map.new(opts)}

  @impl PhoenixAssets.Plugin
  def generated_files(ctx, state) do
    locales = locales(state)
    default = Map.get(state, :default_locale, List.first(locales) || "en")

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

  defp scan_gettext(dir) do
    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.filter(&File.dir?(Path.join(dir, &1)))
    else
      []
    end
  end

  defp render(locales, default) do
    [
      TS.header(),
      "\nexport const locales = #{Jason.encode!(locales)} as const\n",
      "export type Locale = (typeof locales)[number]\n",
      "export const defaultLocale: Locale = #{Jason.encode!(default)}\n"
    ]
    |> IO.iodata_to_binary()
  end
end

if Code.ensure_loaded?(DocShell.Presentation.Asset) do
  defmodule PhoenixAssets.DocShell.Assets do
    @moduledoc """
    Local, prebuilt DocShell browser assets used by hosted and static renderers.

    The JavaScript bundle is generated from `@phoenix-assets/doc-shell/browser`.
    It has no Svelte import, remote URL, source map, or runtime service.
    """

    alias DocShell.Presentation.Asset

    @css_path Path.expand("../../../priv/doc_shell/doc-shell.css", __DIR__)
    @browser_path Path.expand("../../../priv/doc_shell/doc-shell-browser.js", __DIR__)
    @external_resource @css_path
    @external_resource @browser_path
    @css File.read!(@css_path)
    @browser File.read!(@browser_path)

    @budgets %{
      css: %{raw: 49_152, gzip: 12_288},
      browser: %{raw: 49_152, gzip: 16_384}
    }

    @doc "Returns renderer assets at stable logical paths; the exporter content-hashes them."
    @spec all() :: [Asset.t()]
    def all do
      [
        %Asset{path: "doc-shell.css", media_type: "text/css; charset=utf-8", bytes: @css},
        %Asset{
          path: "doc-shell-browser.js",
          media_type: "text/javascript; charset=utf-8",
          bytes: @browser
        }
      ]
    end

    @doc "Returns the declared raw-byte budgets for shipped browser assets."
    @spec budgets() :: %{
            css: %{raw: pos_integer(), gzip: pos_integer()},
            browser: %{raw: pos_integer(), gzip: pos_integer()}
          }
    def budgets, do: @budgets

    @doc "Validates size, remote-import, source-map, and Svelte-free browser constraints."
    @spec validate() :: :ok | {:error, term()}
    def validate do
      cond do
        byte_size(@css) > @budgets.css.raw or gzip_size(@css) > @budgets.css.gzip ->
          {:error, {:asset_budget, :css, measurements(@css), @budgets.css}}

        byte_size(@browser) > @budgets.browser.raw or
            gzip_size(@browser) > @budgets.browser.gzip ->
          {:error, {:asset_budget, :browser, measurements(@browser), @budgets.browser}}

        String.contains?(@browser, ["from\"svelte", "from'svelte", "sourceMappingURL"]) ->
          {:error, :invalid_browser_bundle}

        Regex.match?(~r/(?:src|href)=["']https?:\/\//, @css <> @browser) ->
          {:error, :remote_runtime_asset}

        true ->
          :ok
      end
    end

    defp measurements(bytes), do: %{raw: byte_size(bytes), gzip: gzip_size(bytes)}
    defp gzip_size(bytes), do: bytes |> :zlib.gzip() |> byte_size()
  end
end

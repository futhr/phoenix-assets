defmodule PhoenixAssets.EarlyHints do
  @moduledoc """
  An opt-in plug that sends HTTP 103 Early Hints for a Vite entry's assets.

  Browsers start fetching the entry's stylesheets and module chunks while
  Phoenix is still rendering the response -- the manifest already knows the
  exact link set, so the hints cost one lookup. Mount it in the pipeline that
  renders the HTML shell:

      pipeline :browser do
        # ...
        plug PhoenixAssets.EarlyHints, entry: "src/app.ts"
      end

  Emits only when a production manifest is loaded and the adapter supports
  informational responses (`Plug.Conn.inform/3` is a no-op elsewhere; Bandit
  supports it on HTTP/1 and HTTP/2). In development and on a missing manifest
  the connection passes through untouched.

  ## Why

  Early Hints is the standardised successor to HTTP/2 push for cutting
  render-blocking latency, and a manifest-driven pipeline can emit them with
  perfect accuracy -- the same data that renders the tags renders the hints.
  """

  @behaviour Plug

  alias PhoenixAssets.ManifestServer

  @impl Plug
  def init(opts), do: Keyword.fetch!(opts, :entry) && opts

  @impl Plug
  def call(conn, opts) do
    case ManifestServer.manifest() do
      manifest when is_map(manifest) ->
        inform(conn, opts[:entry])

      _ ->
        conn
    end
  end

  defp inform(conn, entry) do
    case PhoenixAssets.entry!(entry) do
      %{file: file, css: css, imports: imports} ->
        links =
          Enum.map(css, &{"link", "<#{&1}>; rel=preload; as=style"}) ++
            Enum.map([file | imports], &{"link", "<#{&1}>; rel=modulepreload"})

        Plug.Conn.inform(conn, :early_hints, links)

      :dev ->
        conn
    end
  rescue
    # A missing manifest entry must not take the request down; the asset tags
    # raise (visibly) later if the entry is genuinely wrong.
    KeyError -> conn
  end
end

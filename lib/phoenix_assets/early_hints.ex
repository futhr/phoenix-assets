defmodule PhoenixAssets.EarlyHints do
  @moduledoc """
  An opt-in plug that sends HTTP 103 Early Hints for a Vite entry's assets.

  Early Hints let browsers start fetching the entry's stylesheets and module
  chunks while Phoenix is still rendering the response. Mount it in the pipeline that
  renders the HTML shell:

      pipeline :browser do
        # ...
        plug PhoenixAssets.EarlyHints, entry: "src/app.ts"
      end

  Emits only when a production manifest is loaded and the adapter supports
  informational responses (`Plug.Conn.inform/3` is a no-op elsewhere; Bandit
  supports it on HTTP/1 and HTTP/2). In development and on a missing manifest
  the connection passes through untouched.

  """

  @behaviour Plug

  @impl Plug
  def init(opts) do
    case Keyword.fetch!(opts, :entry) do
      entry when is_binary(entry) ->
        opts

      other ->
        raise ArgumentError,
              "phoenix_assets: PhoenixAssets.EarlyHints :entry must be a binary, got: #{inspect(other)}"
    end
  end

  @impl Plug
  def call(conn, opts) do
    case PhoenixAssets.entry!(opts[:entry]) do
      %{file: file, css: css, imports: imports} ->
        links =
          Enum.map(css, &{"link", "<#{&1}>; rel=preload; as=style"}) ++
            Enum.map([file | imports], &{"link", "<#{&1}>; rel=modulepreload"})

        Plug.Conn.inform(conn, :early_hints, links)

      :dev ->
        conn
    end
  rescue
    # A missing manifest or entry must not take the request down; the asset tags
    # raise (visibly) later if the entry is genuinely wrong.
    RuntimeError -> conn
    KeyError -> conn
  end
end

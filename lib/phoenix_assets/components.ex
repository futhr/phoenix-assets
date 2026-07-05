if Code.ensure_loaded?(Phoenix.Component) do
  defmodule PhoenixAssets.Components do
    @moduledoc """
    Phoenix function components for emitting Vite assets and mounting Svelte pages.

    `vite_assets/1` renders the correct `<script>`/`<link>` tags for an entry: in
    production it reads the manifest and emits the hashed entry script, its
    stylesheet links, and `modulepreload` hints for its transitive imports (with
    Subresource Integrity when the manifest carries it); in development it points
    at the Vite dev server (and its HMR client).
    `svelte_page/1` renders the mount point a SvelteKit/Svelte client hydrates,
    serialising props as a data attribute.

    Available only when `Phoenix.Component` is present (it is an optional
    dependency); apps that exclude `phoenix_live_view` do not get this
    module.

    ## Why

    Apps that let Phoenix render the HTML shell need a drop-in way to reference
    build output without hard-coding hashes or duplicating dev/prod logic per
    template.
    """

    use Phoenix.Component

    @doc """
    Emits the script and stylesheet tags for a Vite `entry`.

    In development emits the Vite HMR client and the entry as ES modules from the
    dev server; in production emits the hashed entry script, its stylesheet links,
    and `modulepreload` hints for its transitive imports from the manifest.
    """
    attr(:entry, :string, required: true)
    attr(:nonce, :string, default: nil)

    @spec vite_assets(map()) :: Phoenix.LiveView.Rendered.t()
    def vite_assets(assigns) do
      assigns = assign(assigns, :resolved, PhoenixAssets.entry!(assigns.entry))
      render_vite_assets(assigns)
    end

    defp render_vite_assets(%{resolved: :dev} = assigns) do
      assigns =
        assigns
        |> assign(:client_url, PhoenixAssets.vite_dev_url("@vite/client"))
        |> assign(:entry_url, PhoenixAssets.vite_dev_url(assigns.entry))

      ~H"""
      <script type="module" src={@client_url} nonce={@nonce}></script>
      <script type="module" src={@entry_url} nonce={@nonce}></script>
      """
    end

    # `phx-track-static` lets LiveView detect stale clients after a deploy;
    # the nonce goes on the modulepreload links too -- under a nonce-based
    # script-src policy the preload fetches are otherwise blocked.
    defp render_vite_assets(%{resolved: %{file: _}} = assigns) do
      ~H"""
      <link :for={href <- @resolved.css} rel="stylesheet" href={href} nonce={@nonce} phx-track-static />
      <link
        :for={href <- @resolved.imports}
        rel="modulepreload"
        href={href}
        integrity={@resolved.integrity[href]}
        crossorigin={@resolved.integrity[href] && "anonymous"}
        nonce={@nonce}
      />
      <script
        type="module"
        src={@resolved.file}
        integrity={@resolved.integrity[@resolved.file]}
        crossorigin={@resolved.integrity[@resolved.file] && "anonymous"}
        nonce={@nonce}
        phx-track-static
      ></script>
      """
    end

    @doc """
    Renders the mount point for a Svelte page, serialising `props` for hydration.

    Props are encoded with the stdlib `JSON` module: plain maps, lists, and
    scalars work as-is; structs must derive or implement the `JSON.Encoder`
    protocol.
    """
    attr(:name, :string, required: true)
    attr(:props, :map, default: %{})
    attr(:id, :string, default: nil)

    @spec svelte_page(map()) :: Phoenix.LiveView.Rendered.t()
    def svelte_page(assigns) do
      assigns = assign(assigns, :id, assigns.id || "svelte-" <> assigns.name)

      ~H"""
      <div id={@id} data-svelte-page={@name} data-props={JSON.encode!(@props)}></div>
      """
    end

    @doc """
    Emits a Speculation Rules prefetch block for the app's page routes.

    Reads the page routes from the asset graph (or takes them via `:routes`,
    e.g. from a `PhoenixAssets.Graph.Compiled` module, to avoid a graph read
    per render) and emits a `<script type="speculationrules">` document-rules
    block. Progressive enhancement: browsers without the Speculation Rules API
    ignore the tag. Renders nothing when no routes are known.
    """
    attr(:routes, :list, default: nil)
    attr(:eagerness, :string, default: "moderate", values: ~w(conservative moderate eager))
    attr(:nonce, :string, default: nil)

    @spec speculation_rules(map()) :: Phoenix.LiveView.Rendered.t()
    def speculation_rules(assigns) do
      routes = assigns.routes || graph_page_routes()
      assigns = assign(assigns, :json, speculation_json(routes, assigns.eagerness))

      ~H"""
      <script :if={@json} type="speculationrules" nonce={@nonce}>
        <%= Phoenix.HTML.raw(@json) %>
      </script>
      """
    end

    defp graph_page_routes do
      PhoenixAssets.graph()
      |> Map.get("pages", %{})
      |> Enum.map(fn {_, data} -> data["route"] end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort()
    end

    defp speculation_json([], _), do: nil

    defp speculation_json(routes, eagerness) do
      %{
        "prefetch" => [
          %{
            "where" => %{"or" => Enum.map(routes, &%{"href_matches" => &1})},
            "eagerness" => eagerness
          }
        ]
      }
      # `<` must not appear raw inside a script element ("</script>" would end
      # it); JSON-escape it instead.
      |> JSON.encode!()
      |> String.replace("<", "\\u003c")
    end
  end
end

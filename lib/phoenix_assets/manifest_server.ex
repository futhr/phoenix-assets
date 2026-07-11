defmodule PhoenixAssets.ManifestServer do
  @moduledoc """
  Holds the parsed Vite manifest for fast, lock-free reads.

  In production the manifest is static, so it is parsed once at boot and stored in
  `:persistent_term` for zero-copy concurrent reads. In development the build
  output is constantly changing, so `manifest/0` returns the `:dev` sentinel and
  callers (the components) emit Vite dev-server URLs instead of hashed files.

  """

  use GenServer

  require Logger

  alias PhoenixAssets.Manifest

  @term_key {__MODULE__, :manifest}

  @doc """
  Starts the manifest server.

  Options:

    * `:path` -- the `manifest.json` location. When absent or unreadable, reads
      resolve to `{:error, :missing}`.

  This is a singleton registered under the module name; the cache lives in a
  single `:persistent_term` key, so only one instance runs per node.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the parsed manifest, the `:dev` sentinel in development, or
  `{:error, :missing}` when no manifest is available.
  """
  @spec manifest() :: Manifest.t() | :dev | {:error, :missing}
  def manifest do
    if PhoenixAssets.dev?() do
      :dev
    else
      :persistent_term.get(@term_key, {:error, :missing})
    end
  end

  @doc "Re-reads the manifest from disk and refreshes the cache."
  @spec reload() :: :ok
  def reload, do: GenServer.call(__MODULE__, :reload)

  @impl GenServer
  def init(opts) do
    path = opts[:path]
    :persistent_term.put(@term_key, read(path))
    {:ok, %{path: path}}
  end

  @impl GenServer
  def handle_call(:reload, _, %{path: path} = state) do
    # Only swap the cache on a successful read: a transient failure mid-deploy
    # (manifest momentarily absent or half-written) must not clobber the last-good
    # manifest with `{:error, :missing}` and break production asset serving.
    case read(path) do
      {:error, :missing} -> :ok
      manifest -> :persistent_term.put(@term_key, manifest)
    end

    {:reply, :ok, state}
  end

  defp read(nil), do: {:error, :missing}

  defp read(path) do
    case Manifest.load(path) do
      {:ok, manifest} ->
        manifest

      {:error, reason} ->
        Logger.debug("phoenix_assets: could not read manifest at #{path}: #{inspect(reason)}")
        {:error, :missing}
    end
  end
end

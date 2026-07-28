defmodule Mix.Tasks.PhoenixAssets.Clean do
  @moduledoc """
  Removes the files this library generates.

  Useful to force a clean regeneration, or to verify the cold-start path where
  the Vite plugin must fall back to typed stubs.

  Only the plugins' own files are removed, and only while their contents still
  match what the plugins produce. Anything else in the generated directory stays:
  hosts co-locate their own artifacts there, and a directory-wide `rm -rf`
  deleted hand-written files that took real work to reconstruct.

  Pass `--all` to remove the directory outright when you genuinely want it gone.
  """
  @shortdoc "Remove generated frontend contracts"

  use Mix.Task

  alias PhoenixAssets.{Context, Generated, MixHelpers}

  @impl Mix.Task
  def run(argv) do
    {opts, _} = OptionParser.parse!(argv, strict: [all: :boolean])
    ctx = MixHelpers.context!(env: Mix.env())
    dir = Context.generated_path(ctx)

    if opts[:all], do: remove_all(dir), else: remove_generated(ctx, dir)
  end

  defp remove_all(dir) do
    _ = File.rm_rf!(dir)
    Mix.shell().info("phoenix_assets: removed #{dir}")
  end

  defp remove_generated(ctx, dir) do
    case Generated.clean(ctx) do
      {:ok, %{removed: removed, kept: kept}} ->
        Mix.shell().info("phoenix_assets: removed #{length(removed)} generated file(s) in #{dir}")
        report_kept(kept)

      {:error, reason} ->
        Mix.raise("phoenix_assets.clean: #{inspect(reason)}")
    end
  end

  defp report_kept([]), do: :ok

  defp report_kept(kept) do
    Mix.shell().info(
      "phoenix_assets: kept #{length(kept)} file(s) that differ from generated output:\n" <>
        Enum.map_join(kept, "\n", &"  #{&1}")
    )
  end
end

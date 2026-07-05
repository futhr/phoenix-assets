defmodule Mix.Tasks.PhoenixAssets.Doctor do
  @moduledoc """
  Runs phoenix_assets diagnostics and prints a grouped report.

      mix phoenix_assets.doctor
      mix phoenix_assets.doctor --production   # also run build-time checks

  Exits non-zero when any check fails, so it can gate a deploy.
  """
  @shortdoc "Run phoenix_assets diagnostics"

  use Mix.Task

  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: [production: :boolean])
    ctx = PhoenixAssets.MixHelpers.context!(env: Mix.env())

    {status, results} = PhoenixAssets.Doctor.run(ctx, production: opts[:production] || false)
    Enum.each(results, &report/1)

    if status == :error, do: Mix.raise("phoenix_assets: doctor found errors")
  end

  defp report({check, %{status: status, message: message, hint: hint}}) do
    Mix.shell().info("[#{status}] #{check.group}/#{check.id}: #{message}#{hint_suffix(hint)}")
  end

  defp hint_suffix(nil), do: ""
  defp hint_suffix(hint), do: " -> #{hint}"
end

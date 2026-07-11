defmodule PhoenixAssets.Generators.Env do
  @moduledoc """
  Generates a typed, allow-listed environment module for the frontend.

  Emits `env.ts` from the explicitly exposed values under
  `config :phoenix_assets, :env, expose: [...]`. Only the listed keys are
  emitted -- nothing is read from the OS environment at generation time -- so the
  output is deterministic and no secret can leak by accident.

  ## Configuration

      config :phoenix_assets, :env,
        expose: [app_name: "MyApp", deployment_env: "dev", public_api_base: "/api"]

  ## Example output

      export const env = {
        appName: "MyApp",
        deploymentEnv: "dev",
        publicApiBase: "/api",
      } as const

  """

  alias PhoenixAssets.{Context, GeneratedFile}
  alias PhoenixAssets.Generators.TS

  @doc "Generates the `env.ts` contract from the exposed env values."
  @spec generate(Context.t()) :: GeneratedFile.t()
  def generate(%Context{} = ctx) do
    exposed =
      ctx.config.env_expose
      |> Keyword.get(:expose, [])
      |> Enum.sort_by(fn {key, _} -> key end)

    ensure_unique_keys!(exposed)

    GeneratedFile.new(
      path: Path.join(ctx.generated_dir, "env.ts"),
      contents: render(exposed),
      plugin: :env,
      kind: :env
    )
  end

  defp ensure_unique_keys!(exposed) do
    exposed
    |> Enum.group_by(fn {key, _} -> TS.camelize(key) end)
    |> Enum.find(fn {_, values} -> length(values) > 1 end)
    |> case do
      nil ->
        :ok

      {generated, values} ->
        keys = Enum.map(values, fn {key, _} -> key end)

        raise ArgumentError,
              "phoenix_assets: exposed env keys #{inspect(keys)} both generate #{inspect(generated)}"
    end
  end

  defp render(exposed) do
    [
      TS.header(),
      "\nexport const env = {\n",
      Enum.map(exposed, fn {key, value} ->
        "  #{key |> TS.camelize() |> TS.object_key()}: #{JSON.encode!(value)},\n"
      end),
      "} as const\n"
    ]
  end
end

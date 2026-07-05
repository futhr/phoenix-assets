defmodule PhoenixAssets.DSL do
  @moduledoc false

  @doc """
  Raises a `CompileError` at the caller's location for an invalid declaration.

  `kind` is the declaration word (`"shape"`, `"topic"`, `"type"`) and `name` the
  declared name, giving a uniform `phoenix_assets <kind> <name>: <message>`
  description so drifted declarations fail at compile time, not mid-generation.
  """
  @spec compile_error!(Macro.Env.t(), String.t(), term(), String.t()) :: no_return()
  def compile_error!(env, kind, name, message) do
    raise CompileError,
      file: env.file,
      line: env.line,
      description: "phoenix_assets #{kind} #{inspect(name)}: #{message}"
  end
end

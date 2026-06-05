defmodule PhoenixAssets.Doctor.Check do
  @moduledoc """
  A single diagnostic the doctor can run against a context.

  Plugins contribute checks from `c:PhoenixAssets.Plugin.doctor_checks/2`. A
  check's `run` function receives the `PhoenixAssets.Context` and returns a
  result map describing its status, a human message, and an optional remediation
  hint. Checks flagged `production?: true` also run under
  `mix phoenix_assets.doctor --production`.

  ## Why

  Diagnostics live next to the plugins that understand them (the SvelteKit plugin
  knows what a missing adapter looks like; the Electric plugin knows what a stale
  shape declaration looks like), while the doctor provides a uniform runner and
  report.
  """

  alias PhoenixAssets.Context

  @type status :: :ok | :warn | :error
  @type result :: %{status: status(), message: String.t(), hint: String.t() | nil}

  @type t :: %__MODULE__{
          id: atom(),
          group: atom(),
          run: (Context.t() -> result()),
          production?: boolean()
        }

  @enforce_keys [:id, :run]
  defstruct [:id, :run, group: :general, production?: false]

  @doc "Builds a check from a keyword list or map of attributes."
  @spec new(Enumerable.t()) :: t()
  def new(attrs), do: struct!(__MODULE__, attrs)

  @doc "Builds an `:ok` result."
  @spec ok(String.t()) :: result()
  def ok(message), do: %{status: :ok, message: message, hint: nil}

  @doc "Builds a `:warn` result with an optional remediation hint."
  @spec warn(String.t(), String.t() | nil) :: result()
  def warn(message, hint \\ nil), do: %{status: :warn, message: message, hint: hint}

  @doc "Builds an `:error` result with an optional remediation hint."
  @spec error(String.t(), String.t() | nil) :: result()
  def error(message, hint \\ nil), do: %{status: :error, message: message, hint: hint}
end

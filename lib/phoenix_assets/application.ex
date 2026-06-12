defmodule PhoenixAssets.Application do
  # The library starts nothing of its own: the host adds
  # `PhoenixAssets.child_specs/1` to its tree, where the children can read the
  # host's configuration. This empty supervisor only anchors the OTP app.
  @moduledoc false

  use Application

  @impl Application
  def start(_, _) do
    Supervisor.start_link([], strategy: :one_for_one, name: PhoenixAssets.Supervisor)
  end
end

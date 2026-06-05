defmodule PhoenixAssets.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_, _) do
    children = PhoenixAssets.children()

    Supervisor.start_link(children, strategy: :one_for_one, name: PhoenixAssets.Supervisor)
  end
end

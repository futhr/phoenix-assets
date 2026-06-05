defmodule PhoenixAssets.TailwindTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context, Tailwind}

  defp ctx, do: Context.new(Config.load!(otp_app: :my_app), env: :test)

  test "vite_config/2 records the Tailwind Vite plugin and the default entry" do
    {:ok, state} = Tailwind.init([], ctx())

    assert Tailwind.vite_config(ctx(), state) == %{
             "tailwind" => %{"plugin" => "@tailwindcss/vite", "entry" => "src/app.css"}
           }
  end

  test "vite_config/2 honours a custom :entry" do
    {:ok, state} = Tailwind.init([entry: "css/main.css"], ctx())

    assert %{"tailwind" => %{"entry" => "css/main.css"}} = Tailwind.vite_config(ctx(), state)
  end
end

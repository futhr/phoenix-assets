defmodule PhoenixAssets.LocalizeTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias PhoenixAssets.{Config, Context, Localize}

  defp ctx, do: Context.new(Config.load!(otp_app: :my_app), env: :test)

  test "generates the locale union from an explicit list" do
    {:ok, state} = Localize.init([locales: ~w(en sv), default_locale: "en"], ctx())
    [file] = Localize.generated_files(ctx(), state)
    out = IO.iodata_to_binary(file.contents)

    assert file.kind == :locales
    assert out =~ ~s|export const locales = ["en","sv"] as const|
    assert out =~ "export type Locale = (typeof locales)[number]"
    assert out =~ ~s|export const defaultLocale: Locale = "en"|
  end
end

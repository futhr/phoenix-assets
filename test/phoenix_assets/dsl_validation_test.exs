defmodule PhoenixAssets.DSLValidationTest do
  @moduledoc false

  use ExUnit.Case, async: true

  defp compile!(source), do: Code.compile_string(source)

  defp assert_compile_error(source, message_pattern) do
    error = assert_raise CompileError, fn -> compile!(source) end
    assert Exception.message(error) =~ message_pattern
  end

  describe "Electric.Shapes" do
    test "a shape without a route is a compile error" do
      assert_compile_error(
        """
        defmodule DSLV.NoRoute do
          use PhoenixAssets.Electric.Shapes
          shape :ghost, type: "GhostRow"
        end
        """,
        ~r/shape :ghost.*required :route option not found/s
      )
    end

    test "an unknown shape option is a compile error" do
      assert_compile_error(
        """
        defmodule DSLV.UnknownShapeOpt do
          use PhoenixAssets.Electric.Shapes
          shape :ghost, route: "/shapes/ghost", type: "GhostRow", routes: "/typo"
        end
        """,
        ~r/shape :ghost.*unknown options \[:routes\]/s
      )
    end

    test "params must match the route placeholders exactly" do
      assert_compile_error(
        """
        defmodule DSLV.ParamDrift do
          use PhoenixAssets.Electric.Shapes
          shape :articles, route: "/shapes/users/:user_id/articles",
            type: "ArticleRow", params: [:id]
        end
        """,
        ~r/params \["id"\] do not match the route's placeholders \["user_id"\]/
      )
    end

    test "matching params validate, in any order" do
      [{mod, _}] =
        compile!("""
        defmodule DSLV.ParamsOk do
          use PhoenixAssets.Electric.Shapes
          shape :a, route: "/shapes/:org_id/items/:id", type: "ItemRow", params: [:id, :org_id]
        end
        """)

      assert [a: opts] = mod.__phoenix_assets_shapes__()
      assert opts[:route] == "/shapes/:org_id/items/:id"
    end

    test "glob segments are rejected" do
      assert_compile_error(
        """
        defmodule DSLV.Glob do
          use PhoenixAssets.Electric.Shapes
          shape :files, route: "/shapes/files/*path", type: "FileRow"
        end
        """,
        ~r/glob segments.*not supported in shape routes/
      )
    end

    test "a shape name declared twice is a compile error" do
      assert_compile_error(
        """
        defmodule DSLV.DupShape do
          use PhoenixAssets.Electric.Shapes
          shape :articles, route: "/shapes/articles", type: "ArticleRow"
          shape :articles, route: "/shapes/articles2", type: "ArticleRow"
        end
        """,
        ~r/shape :articles.*declared more than once/s
      )
    end

    test "an invalid generated row type name is a compile error" do
      assert_compile_error(
        """
        defmodule DSLV.BadShapeType do
          use PhoenixAssets.Electric.Shapes
          shape :articles, route: "/shapes/articles", type: "bad-type"
        end
        """,
        ~r/invalid TypeScript type name/
      )
    end
  end

  describe "PubSub.Topics" do
    test "a topic without a pattern is a compile error" do
      assert_compile_error(
        """
        defmodule DSLV.NoPattern do
          use PhoenixAssets.PubSub.Topics
          topic :device, events: [updated: "Device"]
        end
        """,
        ~r/topic :device.*required :pattern option not found/s
      )
    end

    test "a malformed event payload is a compile error" do
      assert_compile_error(
        """
        defmodule DSLV.BadPayload do
          use PhoenixAssets.PubSub.Topics
          topic :device, pattern: "device:{id}", events: [updated: [:not, :valid]]
        end
        """,
        ~r/event :updated payload must be a type name/
      )
    end

    test "an unknown inline primitive is a compile error" do
      assert_compile_error(
        """
        defmodule DSLV.BadPrimitive do
          use PhoenixAssets.PubSub.Topics
          topic :device, pattern: "device", events: [updated: %{id: :wat}]
        end
        """,
        ~r/event :updated payload must be a type name/
      )
    end

    test "valid string, module, and map payloads compile" do
      [{mod, _}] =
        compile!("""
        defmodule DSLV.TopicsOk do
          use PhoenixAssets.PubSub.Topics
          topic :device, pattern: "device:{id}",
            events: [updated: "Device", moved: Some.Row, deleted: %{id: :string}]
        end
        """)

      assert [device: opts] = mod.__phoenix_assets_topics__()
      assert length(opts[:events]) == 3
    end

    test "a topic name declared twice is a compile error" do
      assert_compile_error(
        """
        defmodule DSLV.DupTopic do
          use PhoenixAssets.PubSub.Topics
          topic :device, pattern: "device:{id}"
          topic :device, pattern: "device:{other}"
        end
        """,
        ~r/topic :device.*declared more than once/s
      )
    end

    test "a pattern containing a backtick is rejected" do
      assert_compile_error(
        """
        defmodule DSLV.BacktickPattern do
          use PhoenixAssets.PubSub.Topics
          topic :device, pattern: "device:`{id}`"
        end
        """,
        ~r/must not contain a backtick or `\$\{`/
      )
    end

    test "a pattern containing an interpolation marker (${) is rejected" do
      assert_compile_error(
        ~S"""
        defmodule DSLV.DollarBracePattern do
          use PhoenixAssets.PubSub.Topics
          topic :device, pattern: "device:${id}"
        end
        """,
        ~r/must not contain a backtick or/
      )
    end
  end

  describe "Types.Schema" do
    test "a type without a resource is a compile error" do
      assert_compile_error(
        """
        defmodule DSLV.NoResource do
          use PhoenixAssets.Types.Schema
          type "GhostRow", only: :public
        end
        """,
        ~r/type "GhostRow".*required :resource option not found/s
      )
    end

    test "an invalid :only value is a compile error" do
      assert_compile_error(
        """
        defmodule DSLV.BadOnly do
          use PhoenixAssets.Types.Schema
          type "GhostRow", resource: Some.Resource, only: :everything
        end
        """,
        ~r/type "GhostRow".*:only/s
      )
    end

    test "validated declarations carry their defaults" do
      [{mod, _}] =
        compile!("""
        defmodule DSLV.TypesOk do
          use PhoenixAssets.Types.Schema
          type "OkRow", resource: Some.Resource
        end
        """)

      assert [{"OkRow", opts}] = mod.__phoenix_assets_types__()
      assert opts[:only] == :public
      assert opts[:omit] == []
    end

    test "a type name declared twice is a compile error" do
      assert_compile_error(
        """
        defmodule DSLV.DupType do
          use PhoenixAssets.Types.Schema
          type "GhostRow", resource: Some.Resource
          type "GhostRow", resource: Other.Resource
        end
        """,
        ~r/type "GhostRow".*declared more than once/s
      )
    end

    test "an invalid TypeScript alias is a compile error" do
      assert_compile_error(
        """
        defmodule DSLV.BadTypeName do
          use PhoenixAssets.Types.Schema
          type "bad-name", resource: Some.Resource
        end
        """,
        ~r/invalid TypeScript type name/
      )
    end
  end
end

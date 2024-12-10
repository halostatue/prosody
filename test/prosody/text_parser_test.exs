defmodule Prosody.TextTest do
  use ExUnit.Case, async: true

  alias Prosody.TextParser

  describe "plain text parsing" do
    test "keeps language" do
      assert {:ok, [%{type: :text, content: "Hello world!", language: "fr"}]} =
               TextParser.parse("Hello world!", language: "fr")
    end

    test "creates single text block for any content" do
      assert {:ok, [%{type: :text, content: "Hello world!", language: nil}]} = TextParser.parse("Hello world!")
    end

    test "handles multiline text" do
      assert {:ok, [%{content: "Line 1\nLine 2\nLine 3"}]} = TextParser.parse("Line 1\nLine 2\nLine 3")
    end

    test "handles empty content" do
      assert {:ok, [%{content: ""}]} = TextParser.parse("")
    end

    test "handles whitespace-only content" do
      assert {:ok, [%{content: "   \n\t  \n  "}]} = TextParser.parse("   \n\t  \n  ")
    end

    test "strips frontmatter by default" do
      text = "---\ntitle: Test\n---\nContent here"
      assert {:ok, [%{content: "Content here"}]} = TextParser.parse(text)
    end

    test "preserves frontmatter when configured" do
      text = "---\ntitle: Test\n---\nContent here"
      assert {:ok, [%{content: ^text}]} = TextParser.parse(text, strip_frontmatter: false)
    end

    test "bang version returns blocks directly" do
      assert [%{content: "Hello world!"}] = TextParser.parse!("Hello world!")
    end
  end
end

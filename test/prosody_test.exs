defmodule ProsodyTest do
  use ExUnit.Case, async: true

  doctest Prosody

  describe "analyze_blocks/2" do
    test "processes single content block with default analyzer" do
      block = %{
        type: :text,
        content: "Hello world",
        language: nil,
        metadata: %{}
      }

      {:ok, [result]} = Prosody.analyze_blocks(block)

      assert is_integer(result.words)
      assert is_integer(result.reading_words)
      assert is_map(result.metadata)
    end

    test "processes list of content blocks with default analyzers" do
      blocks = [
        %{type: :text, content: "Hello world", language: nil, metadata: %{}},
        %{type: :code, content: "puts 'hi'", language: "ruby", metadata: %{}}
      ]

      {:ok, results} = Prosody.analyze_blocks(blocks)

      assert length(results) == 2

      assert Enum.all?(results, fn result ->
               is_integer(result.words) and is_integer(result.reading_words) and
                 is_map(result.metadata)
             end)
    end

    test "bang version returns result directly on success" do
      block = %{
        type: :text,
        content: "Hello world",
        language: nil,
        metadata: %{}
      }

      [result] = Prosody.analyze_blocks!(block)

      assert is_integer(result.words)
      assert is_integer(result.reading_words)
      assert is_map(result.metadata)
    end
  end

  describe "summarize/2" do
    test "basic functionality is implemented" do
      analysis = %{
        words: 10,
        reading_words: 10,
        lines: 0,
        metadata: %{}
      }

      assert {:ok, summary} = Prosody.summarize(analysis)
      assert is_map(summary)
      assert Map.has_key?(summary, :words)
      assert Map.has_key?(summary, :reading_time)
      assert Map.has_key?(summary, :code)
      assert Map.has_key?(summary, :metadata)
    end

    test "bang version returns result directly on success" do
      analysis = %{
        words: 10,
        reading_words: 10,
        lines: 0,
        metadata: %{}
      }

      summary = Prosody.summarize!(analysis)
      assert is_map(summary)
      assert Map.has_key?(summary, :words)
    end
  end

  describe "analyze/2" do
    test "analyzes content with default settings" do
      content = "Hello world"
      assert {:ok, summary} = Prosody.analyze(content)
      assert summary.words >= 0
      assert is_integer(summary.reading_time) or is_nil(summary.reading_time)
    end

    @tag :skip
    test "analyzes markdown content" do
      content = "# Hello\n\nThis is **bold** text.\n\n```elixir\nIO.puts(\"hello\")\n```"
      assert {:ok, summary} = Prosody.analyze(content, parser: :markdown)
      assert summary.words > 0
      assert summary.code != nil
      assert summary.code.words > 0
      assert summary.code.lines > 0
    end

    test "analyzes plain text content" do
      content = "Hello world, this is plain text."
      assert {:ok, summary} = Prosody.analyze(content, parser: :text)
      assert summary.words > 0
      assert summary.code == nil
    end

    test "supports parser tuple syntax" do
      content = "---\ntitle: Test\n---\n\nHello world"

      # With frontmatter stripping (default)
      assert {:ok, summary1} = Prosody.analyze(content, parser: {:markdown, strip_frontmatter: true})

      # Without frontmatter stripping
      assert {:ok, summary2} = Prosody.analyze(content, parser: {:markdown, strip_frontmatter: false})

      # Should have different word counts due to frontmatter handling
      assert summary1.words != summary2.words
    end

    test "auto-detects markdown format" do
      content = "# Hello\n\nThis is markdown."
      assert {:ok, summary} = Prosody.analyze(content)
      assert summary.words > 0
    end

    test "auto-detects text format" do
      content = "This is plain text without markdown."
      assert {:ok, summary} = Prosody.analyze(content)
      assert summary.words > 0
    end

    test "handles custom analyzer configuration" do
      content = "Hello world"
      assert {:error, _reason} = Prosody.analyze(content, analyzers: [])
    end

    test "handles custom reading speed" do
      content = "Hello world"
      assert {:ok, summary} = Prosody.analyze(content, words_per_minute: 300)
      assert summary.words > 0
    end

    test "bang version returns result directly" do
      content = "Hello world"
      summary = Prosody.analyze!(content)
      assert summary.words > 0
    end

    test "raises on error" do
      content = "Hello world"

      assert_raise Prosody.Error, fn ->
        Prosody.analyze!(content, parser: :invalid)
      end
    end
  end
end

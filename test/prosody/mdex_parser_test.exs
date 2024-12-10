defmodule Prosody.MDExParserTest do
  use ExUnit.Case, async: true

  alias Prosody.MDExParser

  @gfm_options [
    extension: [
      table: true,
      strikethrough: true,
      autolink: true,
      tasklist: true
    ]
  ]

  describe "markdown link extraction" do
    test "preserves language opt" do
      assert {:ok, [%{content: "Click here", language: "fr"}, %{content: " for more info", language: "fr"}]} =
               MDExParser.parse("[Click here](https://example.com) for more info", language: "fr")
    end

    test "extracts link text from [text](url)" do
      assert ["Click here", " for more info"] = parse_and_extract("[Click here](https://example.com) for more info")
    end

    test "extracts text from multiple links" do
      assert ["Visit ", "GitHub", " and ", "Google", " today"] =
               parse_and_extract("Visit [GitHub](https://github.com) and [Google](https://google.com) today")
    end

    test "extracts text from links with complex content" do
      assert ["Bold link text", " and ", "italic link"] =
               parse_and_extract("[**Bold link text**](https://example.com) and [_italic link_](https://test.org)")
    end

    test "handles links in headers" do
      assert ["Header Link"] = parse_and_extract("# [Header Link](https://example.com)")
    end

    test "handles nested emphasis in links" do
      assert ["Check out ", "this ", "amazing", " resource", " now"] =
               parse_and_extract("Check out [this **amazing** resource](https://example.com) now")
    end
  end

  describe "emphasis marker removal" do
    test "removes bold markers and extracts text" do
      assert ["This is ", "bold text", " in a sentence"] = parse_and_extract("This is **bold text** in a sentence")

      assert ["This is ", "bold text", " in a sentence"] = parse_and_extract("This is __bold text__ in a sentence")
    end

    test "removes italic markers and extracts text" do
      assert ["This is ", "italic text", " in a sentence"] = parse_and_extract("This is *italic text* in a sentence")

      assert ["This is ", "italic text", " in a sentence"] = parse_and_extract("This is _italic text_ in a sentence")
    end

    test "handles combined emphasis markers" do
      assert ["Text with ", "bold", " and ", "italic", " and ", "both"] =
               parse_and_extract("Text with **bold** and *italic* and **_both_**")
    end

    test "handles nested emphasis" do
      assert ["This is ", "really important", " text"] = parse_and_extract("This is ***really important*** text")
    end

    test "handles emphasis in different contexts" do
      markdown = """
      # Header with **bold**

      Paragraph with *italic* text.

      - List item with **bold** text
      """

      assert ["Header with ", "bold", "Paragraph with ", "italic", " text.", "List item with ", "bold", " text"] =
               parse_and_extract(markdown)
    end
  end

  describe "inline code inclusion" do
    test "includes inline code content in text counting" do
      assert ["Use the ", "print()", " function to output text"] =
               parse_and_extract("Use the `print()` function to output text")
    end

    test "handles multiple inline code segments" do
      assert ["Variables like ", "x", " and ", "y", " are common in ", "math", " equations"] =
               parse_and_extract("Variables like `x` and `y` are common in `math` equations")
    end

    test "handles inline code in different contexts" do
      markdown = """
      # Using `grep` Command

      The `grep` command searches for patterns.

      - Use `grep -r` for recursive search
      - Try `grep -i` for case-insensitive search
      """

      assert [
               "Using ",
               "grep",
               " Command",
               "The ",
               "grep",
               " command searches for patterns.",
               "Use ",
               "grep -r",
               " for recursive search",
               "Try ",
               "grep -i",
               " for case-insensitive search"
             ] = parse_and_extract(markdown)
    end

    test "handles inline code with special characters" do
      assert ["Use ", "console.log('Hello, World!')", " to debug"] =
               parse_and_extract("Use `console.log('Hello, World!')` to debug")
    end
  end

  describe "header text extraction" do
    test "extracts text from all header levels" do
      markdown = """
      # Level 1 Header
      ## Level 2 Header
      ### Level 3 Header
      #### Level 4 Header
      ##### Level 5 Header
      ###### Level 6 Header
      """

      assert [
               "Level 1 Header",
               "Level 2 Header",
               "Level 3 Header",
               "Level 4 Header",
               "Level 5 Header",
               "Level 6 Header"
             ] = parse_and_extract(markdown)
    end

    test "removes hash symbols from extracted text" do
      assert ["Main Title"] = parse_and_extract("# Main Title")
    end

    test "handles headers with emphasis and links" do
      assert ["Important", " ", "Link", " Header"] =
               parse_and_extract("# **Important** [Link](https://example.com) Header")
    end

    test "handles headers with inline code" do
      assert ["Using the ", "Array.map()", " Method"] = parse_and_extract("## Using the `Array.map()` Method")
    end
  end

  describe "content block order preservation" do
    test "preserves text language" do
      markdown = """
      # Header

      First paragraph with **bold** text.

      ```elixir
      def hello, do: :world
      ```

      Second paragraph with [link](https://example.com).
      """

      assert {:ok, blocks} = MDExParser.parse(markdown, language: "fr")
      assert [:text, :text, :text, :text, :code, :text, :text, :text] = Enum.map(blocks, & &1.type)
      assert ["fr", "fr", "fr", "fr", "elixir", "fr", "fr", "fr"] = Enum.map(blocks, & &1.language)
      assert ["def hello, do: :world\n"] = extract_contents(blocks, :code)

      assert ["Header", "First paragraph with ", "bold", " text.", "Second paragraph with ", "link", "."] =
               extract_contents(blocks, :text)
    end

    test "preserves document order of mixed content" do
      markdown = """
      # Header

      First paragraph with **bold** text.

      ```elixir
      def hello, do: :world
      ```

      Second paragraph with [link](https://example.com).
      """

      assert {:ok, blocks} = MDExParser.parse(markdown)
      assert [:text, :text, :text, :text, :code, :text, :text, :text] = Enum.map(blocks, & &1.type)
      assert [nil, nil, nil, nil, "elixir", nil, nil, nil] = Enum.map(blocks, & &1.language)
      assert ["def hello, do: :world\n"] = extract_contents(blocks, :code)

      assert ["Header", "First paragraph with ", "bold", " text.", "Second paragraph with ", "link", "."] =
               extract_contents(blocks, :text)
    end

    test "maintains order with multiple code blocks" do
      markdown = """
      Text before first code.

      ```python
      print("first")
      ```

      Text between code blocks.

      ```javascript
      console.log("second");
      ```

      Text after last code.
      """

      assert {:ok, blocks} = MDExParser.parse(markdown)
      assert [:text, :code, :text, :code, :text] = Enum.map(blocks, & &1.type)
      assert ["print(\"first\")\n", "console.log(\"second\");\n"] = extract_contents(blocks, :code)

      assert ["Text before first code.", "Text between code blocks.", "Text after last code."] =
               extract_contents(blocks, :text)
    end
  end

  describe "code block language preservation" do
    test "preserves language information for fenced code blocks" do
      markdown = """
      ```elixir
      def hello do
        "world"
      end
      ```

      ```python
      def hello():
          return "world"
      ```
      """

      assert {:ok,
              [
                %{type: :code, language: "elixir"} = elixir_block,
                %{type: :code, language: "python"} = python_block
              ] = blocks} =
               MDExParser.parse(markdown)

      assert [] = extract_contents(blocks, :text)

      assert elixir_block.content =~ "def hello do"
      assert elixir_block.content =~ "\"world\""

      assert python_block.content =~ "def hello():"
      assert python_block.content =~ "return \"world\""
    end

    test "handles code blocks without language tags" do
      markdown = """
      ```
      plain text code
      no language specified
      ```
      """

      assert {:ok, [%{type: :code, language: nil, content: "plain text code\nno language specified\n"}]} =
               MDExParser.parse(markdown)
    end

    test "extracts language from info string with additional parameters" do
      markdown = """
      ```javascript {line-numbers}
      console.log("hello");
      ```
      """

      assert {:ok, [%{type: :code, language: "javascript", content: "console.log(\"hello\");\n"}]} =
               MDExParser.parse(markdown)
    end
  end

  describe "complex markdown robustness" do
    test "handles nested structures correctly" do
      markdown = """
      # Main Header

      > This is a blockquote with **bold** text and a [link](https://example.com).
      >
      > - List item in blockquote
      > - Another item with *italic* text

      Regular paragraph with `inline code`.
      """

      assert [
               "Main Header",
               "This is a blockquote with ",
               "bold",
               " text and a ",
               "link",
               ".",
               "List item in blockquote",
               "Another item with ",
               "italic",
               " text",
               "Regular paragraph with ",
               "inline code",
               "."
             ] = parse_and_extract(markdown)
    end

    test "handles tables with links and emphasis" do
      markdown = """
      | Name | Description |
      |------|-------------|
      | **Bold** | [Link text](https://example.com) |
      | *Italic* | `code snippet` |
      """

      assert ["Name", "Description", "Bold", "Link text", "Italic", "code snippet"] =
               parse_and_extract(markdown, @gfm_options)
    end

    test "handles malformed markdown gracefully" do
      markdown = """
      # Unclosed **bold text

      [Incomplete link](

      `Unclosed inline code

      Regular text continues.
      """

      assert [
               "Unclosed **bold text",
               "[Incomplete link](",
               "`Unclosed inline code",
               "Regular text continues."
             ] = parse_and_extract(markdown)
    end

    test "handles deeply nested lists" do
      markdown = """
      - Level 1
        - Level 2 with **bold**
          - Level 3 with [link](https://example.com)
            - Level 4 with `code`
      """

      assert ["Level 1", "Level 2 with ", "bold", "Level 3 with ", "link", "Level 4 with ", "code"] =
               parse_and_extract(markdown)
    end

    test "handles mixed content with code blocks" do
      markdown = """
      # Code Example

      Here's how to use the **important** function:

      ```elixir
      def important_function(param) do
        # This is a comment
        param |> process()
      end
      ```

      ```python
      def important_function(param):
          # This is a comment
          return process(param)
      ```

      ### Shell Commands

          $ ls -la
          $ grep -r "pattern" .

      ## Conclusion

      The `important_function` takes a [parameter](https://docs.example.com).
      """

      assert {:ok, blocks} = MDExParser.parse(markdown)

      assert [:text, :text, :text, :text, :code, :code, :text, :code, :text, :text, :text, :text, :text, :text] =
               Enum.map(blocks, & &1.type)

      assert [
               "Code Example",
               "Here's how to use the ",
               "important",
               " function:",
               "Shell Commands",
               "Conclusion",
               "The ",
               "important_function",
               " takes a ",
               "parameter",
               "."
             ] = extract_contents(blocks, :text)

      assert [%{language: "elixir"} = elixir_block, %{language: "python"} = python_block, %{language: nil} = nil_block] =
               Enum.filter(blocks, &(&1.type == :code))

      assert elixir_block.content =~ "def important_function"
      assert elixir_block.content =~ "# This is a comment"

      assert python_block.content =~ "def important_function"
      assert python_block.content =~ "# This is a comment"

      assert nil_block.content =~ "$ ls -la"
      assert nil_block.content =~ "$ grep -r"
    end
  end

  describe "frontmatter handling" do
    test "strips YAML frontmatter before processing" do
      markdown = """
      ---
      title: "Test Post"
      date: 2024-01-01
      tags: ["test", "markdown"]
      ---

      # Actual Content

      This is the real content that should be processed.
      """

      assert ["Actual Content", "This is the real content that should be processed."] =
               parse_and_extract(markdown, strip_frontmatter: true)
    end

    test "preserves frontmatter when strip_frontmatter is false" do
      markdown = """
      ---
      title: "Test Post"
      date: 2024-01-01
      ---

      # Actual Content

      This is the real content.
      """

      assert ["title: \"Test Post\"", "date: 2024-01-01", "Actual Content", "This is the real content."] =
               parse_and_extract(markdown, strip_frontmatter: false)
    end

    test "handles content without frontmatter" do
      markdown = """
      # Regular Content

      No frontmatter here.
      """

      assert ["Regular Content", "No frontmatter here."] = parse_and_extract(markdown)
    end

    test "handles malformed frontmatter" do
      markdown = """
      ---
      title: "Unclosed frontmatter

      # Content After Malformed Frontmatter

      This should still be processed.
      """

      assert ["title: \"Unclosed frontmatter", "Content After Malformed Frontmatter", "This should still be processed."] =
               parse_and_extract(markdown)
    end
  end

  describe "error handling" do
    test "returns success for valid markdown" do
      markdown = "# Valid MDExParser\n\nThis should work fine."
      assert ["Valid MDExParser", "This should work fine."] = parse_and_extract(markdown)
    end

    test "handles empty content" do
      assert [] = parse_and_extract("")
    end

    test "handles whitespace-only content" do
      assert [] = parse_and_extract("   \n\t  \n  ")
    end

    test "handles content with only frontmatter" do
      markdown = """
      ---
      title: "Only Frontmatter"
      ---
      """

      assert [] = parse_and_extract(markdown)
    end
  end

  describe "configuration and options" do
    test "uses default GFM options when no config provided" do
      markdown = """
      | Name | Value |
      |------|-------|
      | Test | ~~strikethrough~~ |
      """

      assert ["Name", "Value", "Test", "strikethrough"] = parse_and_extract(markdown, @gfm_options)
    end

    test "supports direct option overrides" do
      markdown = "Visit https://example.com for more info"

      assert ["Visit https://example.com for more info"] =
               parse_and_extract(markdown, extension: [autolink: false, table: true])
    end

    if Code.ensure_loaded?(MDExGFM) do
      test "supports MDExGFM plugin for proper GFM parsing" do
        markdown = """
        | Name | Value |
        |------|-------|
        | Test | ~~strikethrough~~ |

        - [x] Completed task
        - [ ] Incomplete task

        Visit https://example.com automatically linked
        """

        assert [
                 "Name",
                 "Value",
                 "Test",
                 "strikethrough",
                 "Completed task",
                 "Incomplete task",
                 "Visit ",
                 "https://example.com",
                 " automatically linked"
               ] = parse_and_extract(markdown, plugins: [MDExGFM])
      end
    end
  end

  defp parse_and_extract(markdown, opts \\ []) do
    {type, opts} = Keyword.pop(opts, :type, :text)
    assert {:ok, blocks} = MDExParser.parse(markdown, opts)
    extract_contents(blocks, type)
  end

  defp extract_contents(blocks, type) do
    blocks
    |> Enum.filter(&(&1.type == type))
    |> Enum.map(& &1.content)
  end
end

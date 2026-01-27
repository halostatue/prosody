if Code.ensure_loaded?(MDEx) do
  defmodule Prosody.MDExParser do
    @moduledoc """
    Markdown content parser for the Prosody content analysis library.

    This module parses markdown to AST using MDEx and extracts linearized content blocks
    for accurate analysis that reflects rendered content rather than raw markdown. Code
    blocks are tagged as `type: :code` so that alternative content analysis is possible.
    """

    @behaviour Prosody.Parser

    alias Prosody.Parser

    @doc """
    Parse Markdown content (from `t:String.t/0` or `t:MDEx.Document.t/0`) into a
    `t:Prosody.block/0` list. Returns `{:ok, blocks}` or `{:error, reason}`.

    ## Options

    Options are ignored when the content is provided as `t:MDEx.Document.t/0`.

    - `:strip_frontmatter` (default: `true`): Whether to strip YAML frontmatter.
    - Other options are passed to MDEx for parsing configuration, including `:plugins`.

    ## Examples

    ```elixir
    iex> Prosody.MDExParser.parse("Hello **world**!")
    {:ok, [
      %{type: :text, content: "Hello ", language: nil, metadata: %{}},
      %{type: :text, content: "world", language: nil, metadata: %{}},
      %{type: :text, content: "!", language: nil, metadata: %{}}
    ]}

    iex> Prosody.MDExParser.parse("Text\\n\\n\`\`\`elixir\\ndef hello, do: :ok\\n\`\`\`")
    {:ok, [
      %{type: :text, content: "Text", language: nil, metadata: %{}},
      %{type: :code, content: "def hello, do: :ok\\n", language: "elixir", metadata: %{}}
    ]}

    iex> document = MDEx.new(markdown: "# Hello")
    iex> Prosody.MDExParser.parse(document)
    {:ok, [%{type: :text, content: "Hello", language: nil, metadata: %{}}]}
    ```
    """
    @impl Parser
    def parse(content, opts \\ [])

    def parse(content, opts) when is_binary(content) do
      {strip?, opts} = Keyword.pop(opts, :strip_frontmatter, true)
      content = if strip?, do: Parser.strip_frontmatter(content), else: content
      {language, opts} = Keyword.pop(opts, :language)

      opts
      |> Keyword.put(:markdown, content)
      |> MDEx.new()
      |> MDEx.Document.run()
      |> parse(language: language)
    end

    def parse(%MDEx.Document{} = document, opts) do
      opts = Keyword.take(opts, [:language])
      {:ok, Enum.reverse(walk_ast(document, opts))}
    rescue
      error -> {:error, "Markdown parsing failed: #{inspect(error)}"}
    end

    @doc """
    Parse Markdown content (from `t:String.t/0` or `t:MDEx.Document.t/0`) into
    a `t:Prosody.block/0` list. Returns `blocks` or raises an error.

    ## Options

    Options are ignored when the content is provided as `t:MDEx.Document.t/0`.

    - `:strip_frontmatter` (default: `true`): Whether to strip YAML frontmatter.
    - Other options are passed to MDEx for parsing configuration, including `:plugins`.

    ## Examples

    ```elixir
    iex> Prosody.MDExParser.parse!("Hello **world**!")
    [
      %{type: :text, content: "Hello ", language: nil, metadata: %{}},
      %{type: :text, content: "world", language: nil, metadata: %{}},
      %{type: :text, content: "!", language: nil, metadata: %{}}
    ]

    iex> Prosody.MDExParser.parse!("Text\\n\\n```elixir\\ndef hello, do: :ok\\n```")
    [
      %{type: :text, content: "Text", language: nil, metadata: %{}},
      %{type: :code, content: "def hello, do: :ok\\n", language: "elixir", metadata: %{}}
    ]

    iex> document = MDEx.new(markdown: "# Hello")
    iex> Prosody.MDExParser.parse!(document)
    [%{type: :text, content: "Hello", language: nil, metadata: %{}}]
    ```
    """
    def parse!(content, opts \\ []) do
      case parse(content, opts) do
        {:ok, result} -> result
        {:error, reason} -> raise Prosody.Error, phase: :parse, reason: reason
      end
    end

    defp walk_ast(%MDEx.Document{nodes: []}, _opts), do: []
    defp walk_ast(%MDEx.Document{nodes: nodes}, opts), do: walk_ast(nodes, [], opts)

    defp walk_ast([], acc, _opts), do: acc
    defp walk_ast([node | rest], acc, opts), do: walk_ast(rest, process_node(node, acc, opts), opts)

    defp process_node(%mod{literal: content}, acc, opts) when mod in [MDEx.Text, MDEx.Code] do
      [create_text_block(content, opts[:language]) | acc]
    end

    defp process_node(%mod{nodes: children}, acc, opts)
         when mod in [MDEx.Emph, MDEx.Heading, MDEx.Link, MDEx.Strong, MDEx.Table, MDEx.TableCell, MDEx.TableRow] do
      walk_ast(children, [], opts) ++ acc
    end

    defp process_node(%MDEx.CodeBlock{literal: content, info: info}, acc, _opts) do
      [create_code_block(content, extract_language_from_info(info)) | acc]
    end

    defp process_node(%{nodes: children}, acc, opts) when is_list(children) do
      walk_ast(children, [], opts) ++ acc
    end

    # Skip other nodes
    defp process_node(_node, acc, _opts), do: acc

    defp create_text_block(content, language) do
      %{type: :text, content: content, language: language, metadata: %{}}
    end

    defp create_code_block(content, language) do
      %{type: :code, content: content, language: language, metadata: %{}}
    end

    defp extract_language_from_info(nil), do: nil
    defp extract_language_from_info(""), do: nil

    defp extract_language_from_info(info) when is_binary(info) do
      # The info string typically starts with the language name
      case String.split(info, " ", parts: 2) do
        [lang | _] when lang != "" -> lang
        _ -> nil
      end
    end
  end
end

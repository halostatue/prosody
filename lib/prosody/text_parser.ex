defmodule Prosody.TextParser do
  @moduledoc """
  Plain text content parser for the Prosody content analysis library. This module provides
  fallback behaviour for plain text content or unknown markup formats.
  """

  @behaviour Prosody.Parser

  alias Prosody.Parser

  @doc """
  Parse plain text content (from `t:String.t/0`) into linear `t:Prosody.block/0` entries.
  Returns `{:ok, blocks}` or `{:error, reason}`.

  ## Options

    - `:strip_frontmatter` (default: `true`): Whether to strip YAML frontmatter.

  ## Examples

  ```elixir
  iex> Prosody.TextParser.parse("Hello world!")
  {:ok, [
    %{type: :text, content: "Hello world!", language: nil, metadata: %{}}
  ]}

  iex> Prosody.TextParser.parse("Text with code blocks")
  {:ok, [
    %{type: :text, content: "Text with code blocks", language: nil, metadata: %{}}
  ]}
  ```
  """
  @impl Parser
  def parse(content, opts \\ []) when is_binary(content) do
    content =
      if Keyword.get(opts, :strip_frontmatter, true) do
        Parser.strip_frontmatter(content)
      else
        content
      end

    {:ok, [%{type: :text, content: content, language: Keyword.get(opts, :language), metadata: %{}}]}
  end

  @doc """
  Parse plain text content (from `t:String.t/0`) into linear `t:Prosody.block/0` entries.
  Returns `blocks` or raises an error.

  ## Options

    - `:strip_frontmatter` (default: `true`): Whether to strip YAML frontmatter.

  ## Examples

  ```elixir
  iex> Prosody.TextParser.parse!("Hello world!")
  [%{type: :text, content: "Hello world!", language: nil, metadata: %{}}]

  iex> Prosody.TextParser.parse!("Text with code blocks")
  [%{type: :text, content: "Text with code blocks", language: nil, metadata: %{}}]
  ```
  """
  def parse!(content, opts \\ []) do
    content
    |> parse(opts)
    |> elem(1)
  end
end

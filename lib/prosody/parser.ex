defmodule Prosody.Parser do
  @moduledoc """
  Behaviour for modules that parse formatted content into `t:Prosody.block/0` lists for
  analysis.
  """

  @doc """
  Parse content blocks from formatted content.

  ## Parameters

  - `content`: the content to parse (the type depends on parser)
  - `opts`: parser-specific options (keyword list)

  ## Returns

  - `{:ok, blocks}` on success where `blocks` is a list of content block maps
  - `{:error, reason}` on failure

  ## Common Options

  All parsers should support the following option:

  - `:strip_frontmatter` - Whether to remove YAML frontmatter (default: true)

  Additional options are parser-specific and documented in the parser.
  """
  @callback parse(content :: term(), opts :: keyword()) ::
              {:ok, [Prosody.block()]} | {:error, String.t()}

  @doc """
  Strips frontmatter from binary content in a uniform way. Only works for YAML frontmatter
  patterns, not Hugo's TOML frontmatter pattern.
  """
  def strip_frontmatter(content) do
    if String.starts_with?(content, "---\n") do
      case String.split(content, "\n---\n", parts: 2) do
        [_frontmatter, rest] -> rest
        [_] -> content
      end
    else
      content
    end
  end
end

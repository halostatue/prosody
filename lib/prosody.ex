defmodule Prosody do
  @moduledoc """
  Prosody is a content analysis library that measures reading flow and cognitive load for
  mixed text and code content.

  The library provides a three-stage processing pipeline:

  1. **Parsing**: format-specific parsers convert content into interleaved content blocks
  2. **Analysis**: block analyzers summarize each content block using configurable
     algorithms
  3. **Summarization**: aggregates results into final metrics including reading time

  Prosody includes:

  - `Prosody.MDExParser`: a markdown parser based on MDEx

  - `Prosody.TextParser`: a plain text parser

  - `Prosody.CodeAnalyzer`: a code block analyzer that attempts to apply cognitive load
    adjustments that aren't captured by simple word counting

  - `Prosody.TextAnalyzer`: an text analyzer that emulates word-processor counting
    algorithms based on configuration. There are three short-hand configurations:

    - `:balanced` (default): splits words in a way that matches human intuition.
      It counts hyphenated words (`fast-paced`) and alternating words (`and/or`) as
      separate words, and counts formatted numbers (`1,234`) as single words. Balanced
      resembles Apple Pages.

    - `:minimal`: splits words on spaces. It counts `fast-paced` and `and/or` as one word,
      but counts `and / or` as two words. Minimal resembles Microsoft Word or LibreOffice
      Writer.

    - `:maximal`: splits words on space and punctuation producing the highest word count.
      It counts hyphenated words (`fast-paced`), alternating words (`and/or`, `and / or`)
      and formatted numbers (`1,234`) each as separate words. Maximal resembles Google
      Pages.

    The algorithm results are sometimes surprising, but are consistent:

    | Example           | `:balanced` | `:minimal` | `:maximal` |
    | ----------------- | ----------- | ---------- | ---------- |
    | `two words`       | 2           | 2          | 2          |
    | `and/or`          | 2           | 1          | 2          |
    | `and / or`        | 2           | 2          | 2          |
    | `fast-paced`      | 2           | 1          | 2          |
    | `1,234.56`        | 1           | 1          | 3          |
    | `www.example.com` | 1           | 1          | 3          |
    | `bob@example.com` | 1           | 1          | 3          |

    A longer result on the sentence:

    > The CEO's Q3 buy/sell analysis shows revenue increased 23.8% year-over-year,
    > reaching $4.2M through our e-commerce platform at shop.company.co.uk. Email
    > investors@company.com for the full profit/loss report.

    - `:balanced` produces 30 words
    - `:minimal` produces 25 words
    - `:maximal` produces 37 words

    For details, see `Prosody.TextAnalyzer`.

  ## Example Usage

  ```elixir
  content = "# Hello World\n\nThis is some text.\n\n```elixir\nIO.puts(\"Hello\")\n```"

  # Separated pipeline
  with {:ok, blocks} <- Prosody.MDExParser.parse(content),
       {:ok, results} <- Prosody.analyze_blocks(blocks),
       {:ok, summary} <-  Prosody.summarize(results) do
    render(:analysis, content: content, summary: summary)
  end

  # Convenience wrapper
  render(:analysis, content: content, summary: Prosody.analyze!(content, parser: :markdown))
  ```
  """

  @typedoc """
  A content block represents a segment of content with type and metadata.

  - `type`: the content type (`:text` or `:code`)
  - `content`: the actual content string
  - `language`: optional language hint (code block language or an ISO 3166-1 alpha-2
    language code)
  - `metadata`: parser-specific metadata
  """
  @type block :: %{
          type: :text | :code,
          content: String.t(),
          language: nil | String.t(),
          metadata: map()
        }

  @typedoc """
  Analysis result from processing a content block.

  - `words`: actual word count
  - `reading_words`: words adjusted for cognitive load (might differ from `words`)
  - `lines`: optional number of lines (relevant for code blocks)
  - `metadata`: analyzer-specific metadata
  """
  @type analysis :: %{
          optional(:lines) => nil | non_neg_integer(),
          words: non_neg_integer(),
          reading_words: non_neg_integer(),
          metadata: map()
        }

  @typedoc """
  Final summary of content analysis.

  - `words`: total reading word count, which can include cognitive load adjustments and is
    `reading_words` from `t:analysis/0`
  - `reading_time`: estimated reading time in minutes
  - `code`: code block metrics with `words` and `lines` (nil if there are no code blocks)
  - `text`: text block metrics with `words` (nil if there are no text blocks)
  - `metadata`: summary-specific metadata
  """
  @type summary :: %{
          words: non_neg_integer(),
          reading_time: nil | non_neg_integer(),
          code: nil | %{words: non_neg_integer(), lines: non_neg_integer()},
          text: nil | %{words: non_neg_integer()},
          metadata: map()
        }

  analyze_options = ~S"""
  ## Options

  - `analyzers`: a list of analyzers to run over the blocks
  """

  @doc """
  Analyze content blocks using configured analyzers. Returns `{:ok, result}` or
  `{:error, reason}`.

  #{analyze_options}
  """
  @spec analyze_blocks(block() | [block()], keyword()) ::
          {:ok, [analysis()]} | {:error, String.t()}
  defdelegate analyze_blocks(blocks, opts \\ []), to: Prosody.Analyzer, as: :analyze

  @doc """
  Analyze content blocks using configured analyzers. Returns the result or raises an
  error.

  #{analyze_options}
  """
  @spec analyze_blocks!(block() | [block()], keyword()) :: [analysis()]
  defdelegate analyze_blocks!(blocks, opts \\ []), to: Prosody.Analyzer, as: :analyze!

  summarize_options = ~S"""
  ## Options

  - `words_per_minute`: reading speed for time calculation (default: 200 wpm)
  - `min_reading_time`: minimum reading time in minutes (default: 1 minute)
  """

  @doc """
  Summarize analysis results into final metrics. Returns `{:ok, summary}` or
  `{:error, reason}`.

  #{summarize_options}

  ## Examples

  ```elixir
  {:ok, summary} = Prosody.summarize(analysis, words_per_minute: 250)
  ```
  """
  @spec summarize(analysis() | [analysis()], keyword()) ::
          {:ok, summary()} | {:error, String.t()}
  def summarize(analysis, opts \\ []) do
    words_per_minute = Keyword.get(opts, :words_per_minute, 200)
    min_reading_time = Keyword.get(opts, :min_reading_time, 1)
    analysis = List.wrap(analysis)

    with :ok <- validate_words_per_minute(words_per_minute),
         :ok <- validate_min_reading_time(min_reading_time) do
      aggregate_analysis(analysis, words_per_minute, min_reading_time)
    end
  end

  @doc """
  Summarize analysis results into final metrics. Returns `summary` or raises an error.

  #{summarize_options}

  ## Examples

  ```elixir
  summary = Prosody.summarize!(analysis, words_per_minute: 250)
  ```
  """
  @spec summarize!(analysis() | [analysis()], keyword()) :: summary()
  def summarize!(analysis_results, opts \\ []) do
    case summarize(analysis_results, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise Prosody.Error, phase: :summarize, reason: reason
    end
  end

  parser_options = fn name ->
    """
    ## Options

    - `parser` (default `:text`): the content parser, which must be `:markdown`, `:text`,
    `t:module/0`, or `{parser, opts}`.

    `#{name}/2` passes any other options to the parser specification includes options
    (`{parser, opts}`).
    """
  end

  @doc """
  Parse content blocks from content using parser-specific parsers. Returns `{:ok, blocks}`
  or `{:error, reason}`.

  #{parser_options.("parse")}

  ## Examples

  ```elixir
  {:ok, blocks} = Prosody.parse(content, parser: :markdown)
  {:ok, blocks} = Prosody.parse(content, parser: {:markdown, strip_frontmatter: false})
  {:ok, blocks} = Prosody.parse(content, parser: {MyCustom.Parser, custom_opt: true})
  ```
  """
  @spec parse(String.t(), keyword()) :: {:ok, [block()]} | {:error, String.t()}
  def parse(content, opts \\ []) when is_binary(content) and is_list(opts) do
    {spec, opts} = Keyword.pop(opts, :parser, :text)

    case resolve_parser(spec) do
      {module, opts} when is_atom(module) -> module.parse(content, opts)
      module when is_atom(module) -> module.parse(content, opts)
    end
  rescue
    error -> {:error, "Parsing failed: #{inspect(error)}"}
  end

  @doc """
  Parse content blocks from content using parser-specific parsers. Returns `blocks` or
  raises an error.

  #{parser_options.("parse!")}

  ## Examples

  ```elixir
  {:ok, blocks} = Prosody.parse(content, parser: :markdown)
  {:ok, blocks} = Prosody.parse(content, parser: {:markdown, strip_frontmatter: false})
  {:ok, blocks} = Prosody.parse(content, parser: {MyCustom.Parser, custom_opt: true})
  ```
  """
  @spec parse!(String.t(), keyword()) :: [block()]
  def parse!(content, opts \\ []) do
    case parse(content, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise Prosody.Error, phase: :parse, reason: reason
    end
  end

  analyze_options = fn name ->
    """
    ## Options

    - `parser` (default: `:text`): parser configuration for `parser/2`.
    - `analyzers`: analyzer configuration for `analyze_blocks/2`.
    - `words_per_minute`: reading speed for `summarize/2`.
    - `min_reading_time`: minimum reading time for `summarize/2`.

    `#{name}/2` passes any other options to each pipeline step, except the four noted above.
    """
  end

  @doc """
  Produces `t:summary/0` output with one function call, returning as `{:ok, summary}` or
  `{:error, reason}`.

  #{analyze_options.("analyze")}

  ## Examples

  ```elixir
  # Text parser
  {:ok, summary} = Prosody.analyze(content)

  # Explicit parser
  {:ok, summary} = Prosody.analyze(content, parser: :markdown)

  # Full configuration
  {:ok, summary} = Prosody.analyze(content,
    parser: {:markdown, strip_frontmatter: false},
    analyzers: [MermaidAnalyzer, :default],
    words_per_minute: 250
  )
  ```
  """
  @spec analyze(String.t(), keyword()) :: {:ok, summary()} | {:error, String.t()}
  def analyze(content, opts \\ []) when is_binary(content) do
    {parser, opts} = Keyword.pop(opts, :parser, :text)
    {analyzers, opts} = Keyword.pop(opts, :analyzers, :default)

    {summarize, opts} =
      {Keyword.take(opts, [:words_per_minute, :min_reading_time]),
       Keyword.drop(opts, [:words_per_minute, :min_reading_time])}

    parser_opts = Keyword.put(opts, :parser, parser)
    analyze_opts = Keyword.put(opts, :analyzers, analyzers)
    summarize_opts = summarize ++ opts

    with {:ok, blocks} <- parse(content, parser_opts),
         {:ok, analysis} <- analyze_blocks(blocks, analyze_opts) do
      summarize(analysis, summarize_opts)
    end
  end

  @doc """
  Produces `t:summary/0` output with one function call, or raises an error.

  #{analyze_options.("analyze!")}

  ## Examples

  ```elixir
  # Text parser
  summary = Prosody.analyze!(content)

  # Explicit parser
  summary = Prosody.analyze!(content, parser: :markdown)

  # Full configuration
  summary = Prosody.analyze!(content,
    parser: {:markdown, strip_frontmatter: false},
    analyzers: [MermaidAnalyzer, :default],
    words_per_minute: 250
  )
  ```
  """
  @spec analyze!(String.t(), keyword()) :: summary()
  def analyze!(content, opts \\ []) do
    case analyze(content, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise Prosody.Error, phase: :analyze, reason: reason
    end
  end

  defp aggregate_analysis(analysis, words_per_minute, min_reading_time) do
    aggregate =
      Enum.reduce(
        analysis,
        %{text_words: 0, reading_words: 0, code_words: 0, code_lines: 0},
        &aggregate_analysis/2
      )

    reading_time =
      if aggregate.reading_words > 0 do
        max(min_reading_time, ceil(aggregate.reading_words / words_per_minute))
      else
        min_reading_time
      end

    code_metrics =
      if aggregate.code_words > 0 or aggregate.code_lines > 0 do
        %{words: aggregate.code_words, lines: aggregate.code_lines}
      end

    text_metrics =
      if aggregate.text_words > 0 do
        %{words: aggregate.text_words}
      end

    {:ok,
     %{
       words: aggregate.reading_words,
       reading_time: reading_time,
       code: code_metrics,
       text: text_metrics,
       metadata: %{}
     }}
  end

  defp aggregate_analysis(result, aggregate) do
    words = result[:words] || 0
    reading_words = result[:reading_words] || 0
    lines = result[:lines] || 0
    code? = get_in(result, [:metadata, :type]) == :code

    if code? do
      %{
        aggregate
        | reading_words: aggregate.reading_words + reading_words,
          code_words: aggregate.code_words + reading_words,
          code_lines: aggregate.code_lines + lines
      }
    else
      %{
        aggregate
        | text_words: aggregate.text_words + words,
          reading_words: aggregate.reading_words + reading_words
      }
    end
  end

  # Resolve parser atom/module to parser module
  defp resolve_parser(:markdown), do: Prosody.MDExParser
  defp resolve_parser(:text), do: Prosody.TextParser
  defp resolve_parser(module) when is_atom(module), do: module
  defp resolve_parser({module, opts}), do: {resolve_parser(module), opts}

  defp validate_words_per_minute(words_per_minute)
       when is_integer(words_per_minute) and words_per_minute > 0 do
    :ok
  end

  defp validate_words_per_minute(other) do
    {:error, "invalid :words_per_minute value #{inspect(other)}, expected positive integer"}
  end

  defp validate_min_reading_time(min_reading_time)
       when is_integer(min_reading_time) and min_reading_time >= 0 do
    :ok
  end

  defp validate_min_reading_time(other) do
    {:error, "invalid :min_reading_time value #{inspect(other)}, expected non-negative integer"}
  end
end

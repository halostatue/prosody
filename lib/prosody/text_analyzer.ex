defmodule Prosody.TextAnalyzer do
  @moduledoc """
  Text content analyzer with support for multiple word counting algorithms emulating
  different word processors.

  This module is the default _fallback_ analyzer, so it will process _any_ content block
  type as if it were text.

  ## Supported Algorithms

  `Prosody.TextAnalyzer` supports three basic algorithms for counting words, each modelled
  after a different word processor. These algorithms are:

  - `:balanced`: The default algorithm, which splits words in a way that matches human
    intution. Hyphenated words (`fast-paced`) and alternating words (`and/or`) are counted
    as separate words. Formatted numbers (`1,234`) are counted as single words. This is
    similar to what Apple Pages does.

  - `:minimal`: This splits words on spaces, so that `fast-paced` and `and/or` are one
    word, but `and / or` is two words. This is most like Microsoft Word or LibreOffice
    Writer.

  - `:maximal`: This splits words on space and punctuation, resulting in the highest word
    count.

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

  > The CEO's Q3 buy/sell analysis shows revenue increased 23.8% year-over-year, reaching
  > $4.2M through our e-commerce platform at shop.company.co.uk. Email
  > investors@company.com for the full profit/loss report.

  - `:balanced` produces 30 words
  - `:minimal` produces 25 words
  - `:maximal` produces 37 words

  Contractions are always preserved as single words for all algorithms.

  ## Options

  Behaviour may be changed by providing configuration options to `analyze/2`.

  - `:algorithm`: The counting algorithm to use. If provided, must be one of `:balanced`,
    `:minimal`, or `:maximal`.

  Explicit feature configuration may be provided with specific options:

  - `:preserve_urls`: Whether to count URLs as single words
  - `:preserve_emails`: Whether to count emails as single words
  - `:preserve_numbers`: Whether to count numbers as single words
  - `:skip_punctuation_words`: Whether "words" that are just punctuation are skipped or
    counted
  - `:word_separators`: A list of characters to make a `t:String.pattern/0` or a regular
    expression indicating how words should be separated. This may not be specified if
    `algorithm` is specified.

  The different algorithms provide different defaults beyond their `word_separators`.

  - `:balanced` and `minimal` preserve URLs, email addresses, and numbers, and skip
    punctuation "words".
  - `:maximal` skips punctuation words but does not preserve URLs, email addresses, or
    numbers by.

  It is permissible to specify `algorithm: :maximal, preserve_urls: true`, where the
  maximal approach will be taken, but URLs will be counted as a single word.

  If no `:algorithm` or `:word_separators` are provided, then `algorithm: :balanced` is
  used.
  """

  @behaviour Prosody.Analyzer

  @impl Prosody.Analyzer
  def analyze(block, opts) do
    {debug?, opts} = Keyword.pop(opts, :debug, false)

    opts =
      Keyword.take(opts, [
        :algorithm,
        :preserve_emails,
        :preserve_numbers,
        :preserve_urls,
        :skip_punctuation_words,
        :word_separators
      ])

    with {:ok, config} <- resolve_config(opts) do
      words = split(block.content, config)
      count = length(words)

      metadata = %{type: block.type, algorithm: config.algorithm}
      metadata = if debug?, do: Map.put(metadata, :debug, %{words: words}), else: metadata

      {:ok, %{words: count, reading_words: count, metadata: metadata}}
    end
  end

  defp resolve_config(opts) do
    {algorithm, opts} = Keyword.pop(opts, :algorithm)
    {word_separators, opts} = Keyword.pop(opts, :word_separators)

    case {algorithm, word_separators} do
      {nil, nil} -> resolve_algorithm(:balanced, opts)
      {value, nil} when value in [:minimal, :balanced, :maximal] -> resolve_algorithm(value, opts)
      {nil, word_separators} -> {:ok, Map.merge(Map.new(opts), %{word_separators: word_separators, algorithm: :manual})}
      {_, _} -> {:error, "Cannot provide `:algorithm` and `:word_separators`"}
    end
  end

  @default_opts %{
    minimal: %{
      word_separators: [" ", "\t", "\n", "\r", "\f", "\v"],
      preserve_urls: true,
      preserve_emails: true,
      preserve_numbers: true,
      skip_punctuation_words: true
    },
    balanced: %{
      word_separators: [" ", "\t", "\n", "\r", "\f", "\v", "-", "/"],
      preserve_urls: true,
      preserve_emails: true,
      preserve_numbers: true,
      skip_punctuation_words: true
    },
    maximal: %{
      word_separators: ~r/[\s[:punct:]]+/u,
      preserve_urls: false,
      preserve_emails: false,
      preserve_numbers: false,
      skip_punctuation_words: true
    }
  }

  defp resolve_algorithm(algorithm, opts) do
    case Map.fetch(@default_opts, algorithm) do
      :error ->
        {:error, "Unknown algorithm #{inspect(algorithm)}"}

      {:ok, defaults} ->
        {:ok, Map.merge(defaults, Map.new(Keyword.put(opts, :algorithm, algorithm)))}
    end
  end

  defp split(content, config) do
    content
    |> preserve_urls(config)
    |> preserve_emails(config)
    |> preserve_numbers(config)
    |> preserve_contractions()
    |> String.split(config.word_separators, trim: true)
    |> filter_punctuation_words(config)
  end

  defp preserve_urls(content, %{preserve_urls: true}) do
    String.replace(content, ~r/https?:\/\/[^\s]+/iu, "URL")
  end

  defp preserve_urls(content, _), do: content

  defp preserve_emails(content, %{preserve_emails: true}) do
    String.replace(content, ~r/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/u, "EMAIL")
  end

  defp preserve_emails(content, _), do: content

  defp preserve_numbers(content, %{preserve_numbers: true}) do
    String.replace(content, ~r/\b(?:\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+\.\d+|\d+\/\d+)\b/u, "NUMBER")
  end

  defp preserve_numbers(content, _), do: content

  defp preserve_contractions(content) do
    String.replace(content, ~r/\b\w+'\w+\b/u, "CONTRACTION")
  end

  defp filter_punctuation_words(words, %{skip_punctuation_words: true}) do
    Enum.reject(words, &String.match?(&1, ~r/^[[:punct:]]+$/u))
  end

  defp filter_punctuation_words(words, _), do: words
end

if Code.ensure_loaded?(Tableau) do
  alias Prosody.MDExParser, as: ProsodyMDExParser

  defmodule Prosody.Tableau do
    @moduledoc """
    A Tableau pre-build extension that uses Prosody to calculate the number of words and
    the reading time for the content of the post.

    ## Configuration

    ```elixir
    config :tableau, Prosody.Tableau,
      enabled: true,
      algorithm: :balanced,
      words_per_minute: 200,
      min_reading_time: 2,
      parsers: [:default, dj: MySite.DjotParser]
    ```

    ### Configuration Options

    - `:enabled` (default `false`): Whether the extension is active

    - `:parsers` (default `:default`): A keyword list of parser configurations, similar to
      the `:converters` Tableau site configuration key. The `:default` key is for any
      posts that do not match the expected configuration. Parsers may be specified as
      `t:module/0` or `{module, opts}`.

      The special value `:default` (either alone or in the parsers list) adds Markdown
      handling with `Prosody.Tableau.MDExParser` (a version of `Prosody.MDExParser` that
      knows how to read configuration from the Tableau MDEx configuration at
      `token.site.config.markdown.mdex`) and a fallback to `Prosody.TextParser` for any
      unknown content type.

      If no parser is configured as `default: module`, then content not matching any
      configured type will be skipped.

    - Analyzer configurations options:

      - `:analyzers`: The list of analyzers passed to the Prosody block analysis phase, as
        documented for `Prosody.Analyzer.analzye/2`.

      - `:algorithm`, `:preserve_urls`, `:preserve_emails`, `:preserve_numbers`,
        `:skip_punctuation_words`, and `:word_separators` are all passed as options to
        `Prosody.TextAnalyzer`, if present.

      See `Prosody.CodeAnalyzer` and `Prosody.TextAnalyzer` for how code analysis is
      performed.

    - Summary configuration options:

      - `:words_per_minute` (default: 200): Reading speed for time estimation
      - `:min_reading_time` (default: 2): Minimum reading time to display

    ## Post Metadata Added

    The resulting `t:Prosody.summary/0` will be added to the post frontmatter under the
    key `:prosody`, resulting in an effective frontmatter of:

    ```yaml
    prosody:
      words: 500
      reading_time: 3
      code:
        words: 75
        lines: 10
      text:
        words: 425
      metadata: {}
    ```

    - `prosody.words`: Total reading word count (may include cognitive load adjustments)
    - `prosody.reading_time`: Estimated reading time in minutes (rounded up)
    - `prosody.code`: `nil` if no code is present in the post, otheriwse contains `words`
      (code words where cognitive load adjustments may apply) and `lines` (total non-blank
      lines of code)
    - `prosody.text`: `nil` if no text is present in the post, otherwise contains `words`
      (words found in the text portions of the post)
    - `prosody.metadata`: Summary-specific metadata. Empty for now.

    ## Opting Out

    Posts can opt out of Prosody calculations by specify `prosody: false` in the post
    frontmatter:

    ```yaml
    ---
    title: "My Post"
    prosody: false
    ---
    ```
    """

    use Tableau.Extension, key: :prosody, priority: 150

    defmodule MDExParser do
      @moduledoc false

      @behaviour Prosody.Parser

      @impl Prosody.Parser
      def parse(content, opts \\ []) do
        {site, opts} = Keyword.pop(opts, :site, [])
        mdex_opts = get_in(site, [:markdown, :mdex]) || []
        ProsodyMDExParser.parse(content, Keyword.merge(mdex_opts, opts))
      end
    end

    @defaults %{enabled: false, parsers: :default}

    @impl Tableau.Extension
    def config(config) when is_list(config), do: config(Map.new(config))

    def config(config) do
      @defaults
      |> Map.merge(config)
      |> validate_and_prepare()
    end

    @impl Tableau.Extension
    def pre_build(token) do
      {:ok,
       Map.put(
         token,
         :posts,
         Enum.map(
           token.posts,
           &process_post(&1, token.extensions.prosody.config, token.site.config)
         )
       )}
    end

    defp process_post(post, config, site_config) do
      if Map.get(post, :prosody) != false and Map.has_key?(post, :file) do
        case analyze_post(post, config, site_config) do
          {:ok, nil} -> post
          {:ok, summary} -> Map.put(post, :prosody, summary)
          {:error, reason} -> Map.put(post, :prosody, %{error: reason})
        end
      else
        post
      end
    end

    defp analyze_post(post, config, site_config) do
      if parser = Map.get(config.parsers, Path.extname(post.file), Map.get(config.parsers, :default)) do
        run_prosody_pipeline(
          post,
          parser,
          Keyword.put(config.parser_opts[parser], :site, site_config),
          config
        )
      else
        {:ok, nil}
      end
    end

    defp run_prosody_pipeline(post, parser, parser_opts, config) do
      with {:ok, blocks} <- parser.parse(post.body, parser_opts),
           {:ok, analysis} <- Prosody.analyze_blocks(blocks, config.analysis_opts) do
        Prosody.summarize(analysis, config.summarize_opts)
      end
    end

    defp validate_and_prepare(config) do
      case Enum.reduce_while(
             config,
             %{analysis_opts: [], enabled: false, parser_opts: %{}, parsers: %{}, summarize_opts: []},
             &prepare_option/2
           ) do
        {:error, reason} -> {:error, reason}
        config -> validate(config)
      end
    end

    defp prepare_option({:enabled, value}, config), do: {:cont, %{config | enabled: value}}
    defp prepare_option({:parsers, value}, config), do: prepare_parsers(config, value)

    defp prepare_option({key, value}, config)
         when key in [
                :analyzers,
                :algorithm,
                :preserve_urls,
                :preserve_emails,
                :preserve_numbers,
                :skip_punctuation_words,
                :word_separators
              ], do: {:cont, %{config | analysis_opts: Keyword.put(config.analysis_opts, key, value)}}

    defp prepare_option({key, value}, config) when key in [:words_per_minute, :min_reading_time],
      do: {:cont, %{config | summarize_opts: Keyword.put(config.summarize_opts, key, value)}}

    defp prepare_option({key, _value}, _config), do: {:halt, {:error, "Unknown configuration option #{key}"}}

    defp prepare_parsers(config, parsers) do
      requested = List.wrap(parsers)

      parsers =
        if Enum.any?(requested, &(&1 == :default)) do
          Keyword.merge(
            [md: MDExParser, default: Prosody.TextParser],
            Enum.reject(requested, &(&1 == :default))
          )
        else
          requested
        end

      {parsers, parser_opts} = Enum.reduce(parsers, {%{}, %{}}, &prepare_parser/2)

      {:cont, %{config | parsers: parsers, parser_opts: parser_opts}}
    end

    @default_parser_opts [strip_frontmatter: false]

    defp prepare_parser({key, {parser, opts}}, {parsers, parser_opts}) do
      key = if key == :default, do: :default, else: ".#{key}"

      {
        Map.put(parsers, key, parser),
        Map.put(parser_opts, parser, Keyword.merge(@default_parser_opts, opts))
      }
    end

    defp prepare_parser({key, parser}, {parsers, parser_opts}) do
      key = if key == :default, do: :default, else: ".#{key}"

      {
        Map.put(parsers, key, parser),
        Map.put(parser_opts, parser, @default_parser_opts)
      }
    end

    defp validate(config) do
      with {:ok, config} <- validate_analysis_opts(config) do
        validate_summarize_opts(config)
      end
    end

    defp validate_analysis_opts(%{analysis_opts: opts} = config) do
      with :ok <- validate_analyzers(opts[:analyzers]),
           :ok <- validate_algorithm(opts[:algorithm]),
           :ok <- validate_boolean(opts[:preserve_urls], :preserve_urls),
           :ok <- validate_boolean(opts[:preserve_emails], :preserve_emails),
           :ok <- validate_boolean(opts[:preserve_numbers], :preserve_numbers),
           :ok <- validate_boolean(opts[:skip_punctuation_words], :skip_punctuation_words),
           {:ok, separators} <- validate_word_separators(opts[:word_separators]) do
        config =
          if separators do
            put_in(config.analysis_opts[:word_separators], separators)
          else
            config
          end

        {:ok, config}
      end
    end

    defp validate_analyzers(value) when value in [nil, :default] or is_list(value), do: :ok
    defp validate_analyzers(_value), do: {:error, "Invalid `:analyzers` option"}

    defp validate_algorithm(value) when value in [nil, :balanced, :maximal, :minimal], do: :ok

    defp validate_algorithm(value),
      do: {:error, "invalid :algorithm value #{inspect(value)}, expected :minimal, :balanced, or :maximal"}

    defp validate_boolean(value, _key) when value in [nil, true, false], do: :ok
    defp validate_boolean(_value, key), do: {:error, "invalid boolean :#{key} value"}

    defp validate_word_separators(nil), do: {:ok, nil}
    defp validate_word_separators(value) when is_struct(value, Regex), do: {:ok, value}

    defp validate_word_separators(value) when is_list(value) do
      {:ok, :binary.compile_pattern(value)}
    rescue
      _ -> {:error, "invalid word_separator pattern list"}
    end

    defp validate_word_separators(value) when is_binary(value), do: Regex.compile(value)

    defp validate_word_separators(_), do: {:error, "invalid word separators"}

    defp validate_summarize_opts(%{summarize_opts: opts} = config) do
      with :ok <- validate_words_per_minute(opts[:words_per_minute]),
           :ok <- validate_min_reading_time(opts[:min_reading_time]) do
        {:ok, config}
      end
    end

    defp validate_words_per_minute(value) when is_nil(value) or (is_integer(value) and value > 0), do: :ok

    defp validate_words_per_minute(other) do
      {:error, "invalid :words_per_minute value #{inspect(other)}, expected positive integer"}
    end

    defp validate_min_reading_time(value) when is_nil(value) or (is_integer(value) and value >= 0), do: :ok

    defp validate_min_reading_time(other) do
      {:error, "invalid :min_reading_time value #{inspect(other)}, expected non-negative integer"}
    end
  end
end

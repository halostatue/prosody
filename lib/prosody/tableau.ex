if Code.ensure_loaded?(Tableau) do
  alias Prosody.MDExParser, as: ProsodyMDExParser

  defmodule Prosody.Tableau do
    @moduledoc """
    A Tableau `pre_build` extension using Prosody to produce post statistics.

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

    - `:enabled` (default `false`): enables the extension

    - `:parsers` (default `:default`): a keyword list of parser configurations, similar to
      the `:converters` Tableau site configuration key. The `:default` key is for any
      posts that don't match the expected configuration. Pass parsers as `t:module/0` or
      `{module, opts}`.

      The special value `:default` (either alone or in the parsers list) sets:

      - `md: Prosody.Tableau.MDExParser`, a version of `Prosody.MDExParser` that
        reads the MDEx configuration from Tableau, and
      - `default: Prosody.TextParser` for unknown content types treated as text.

      This extension skips any content missing a parser without a default parser
      (`default: module`)

    - Analyzer configurations options:

      - `:analyzers`: the list of analyzers passed to `Prosody.Analyzer.analyze/2`.

      - `:algorithm`, `:preserve_urls`, `:preserve_emails`, `:preserve_numbers`,
        `:skip_punctuation_words`, and `:word_separators` are all passed as options to
        `Prosody.TextAnalyzer`, if present.

      See `Prosody.CodeAnalyzer` and `Prosody.TextAnalyzer` for details.

    - Summary configuration options:

      - `:words_per_minute` (default: 200): reading speed for time estimation
      - `:min_reading_time` (default: 1): minimum reading time to display

    ## Post Metadata Added

    The extension inserts `t:Prosody.summary/0` into to the post frontmatter under the
     `:prosody` key:

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

    - `prosody.words`: total reading word count (might include cognitive load adjustments)
    - `prosody.reading_time`: estimated reading time in minutes (rounded up)
    - `prosody.code`: `nil` if no code is present in the post, otherwise an object with
      `words` (code words where cognitive load adjustments might apply) and `lines` (total
      non-blank lines of code)
    - `prosody.text`: `nil` if no text is present in the post, otherwise an object with
      `words` (words found in the text portions of the post)
    - `prosody.metadata`: summary-specific metadata. Empty for now.

    ## Opting Out

    Posts can opt out of Prosody calculations by setting `prosody: false` in the post
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
      @moduledoc """
      A version of `Prosody.MDExParser` that reads the MDEx configuration from Tableau.
      """

      @behaviour Prosody.Parser

      @impl Prosody.Parser
      def parse(content, opts \\ []) do
        {site, opts} = Keyword.pop(opts, :site)
        ProsodyMDExParser.parse(content, Keyword.merge(mdex_opts(site), opts))
      end

      defp site_config do
        case Tableau.Config.get() do
          {:ok, config} -> config
          _ -> %{}
        end
      end

      defp mdex_opts(site) do
        # Tableau 0.31 changes Tableau from having a Converter behaviour to using
        # a converter extension (`Tableau.MDExExtension`). This checks for the
        # configuration there, otherwise it tries to get the configuration from the
        # location _before_ the change.
        #
        # In the unlikely event that _both_ exist, `Tablea.MDExExtension` wins.
        modern = Application.get_env(:tableau, Tableau.MDExExtension, [])

        legacy =
          case Map.fetch(site || site_config(), :markdown) do
            {:ok, markdown} -> markdown[:mdex] || []
            :error -> []
          end

        Keyword.merge(legacy, modern)
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
      ext =
        post
        |> Map.get_lazy(:ext, fn -> Path.extname(post.file) end)
        |> parser_key()

      case Map.get(config.parsers, ext, Map.get(config.parsers, :default)) do
        {parser, parser_opts} ->
          run_prosody_pipeline(post, parser, Keyword.put(parser_opts, :site, site_config), config)

        nil ->
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
             %{analysis_opts: [], enabled: false, parsers: %{}, summarize_opts: []},
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
              ] do
      {:cont, %{config | analysis_opts: Keyword.put(config.analysis_opts, key, value)}}
    end

    defp prepare_option({key, value}, config) when key in [:words_per_minute, :min_reading_time],
      do: {:cont, %{config | summarize_opts: Keyword.put(config.summarize_opts, key, value)}}

    defp prepare_option({key, _value}, _config),
      do: {:halt, {:error, "Unknown configuration option #{key}"}}

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

      {:cont, %{config | parsers: Enum.reduce(parsers, %{}, &prepare_parser/2)}}
    end

    @default_parser_opts [strip_frontmatter: false]

    # Store parser options with the parser for each extension key so that the same parser
    # module can hold different configurations for different extensions.
    defp prepare_parser({key, {parser, opts}}, parsers),
      do: Map.put(parsers, parser_key(key), {parser, Keyword.merge(@default_parser_opts, opts)})

    defp prepare_parser({key, parser}, parsers),
      do: Map.put(parsers, parser_key(key), {parser, @default_parser_opts})

    defp parser_key(:default), do: :default
    defp parser_key("." <> _ = key), do: key
    defp parser_key(key), do: ".#{key}"

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

    defp validate_algorithm(value) do
      {:error,
       "invalid :algorithm value #{inspect(value)}, expected :minimal, :balanced, or :maximal"}
    end

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

    defp validate_words_per_minute(value) when is_nil(value) or (is_integer(value) and value > 0),
      do: :ok

    defp validate_words_per_minute(other) do
      {:error, "invalid :words_per_minute value #{inspect(other)}, expected positive integer"}
    end

    defp validate_min_reading_time(value)
         when is_nil(value) or (is_integer(value) and value >= 0), do: :ok

    defp validate_min_reading_time(other) do
      {:error, "invalid :min_reading_time value #{inspect(other)}, expected non-negative integer"}
    end
  end
end

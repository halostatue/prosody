defmodule Prosody.Analyzer do
  @moduledoc """
  Behaviour for modules that analyze content blocks and return word counts, cognitive load
  adjustments, and other metrics as appropriate to the type of content block.

  Content blocks are `t:Prosody.block/0` produced by `Prosody.Parser` modules.
  """

  @doc """
  Analyze a single content block.

  - `block`: A single content block map (`t:Prosody.block/0`)
  - `opts`: Analyzer-specific options

  ## Returns

  - `{:ok, Prosody.analysis()}` for single content block
  - `{:error, reason}` on failure
  - `:ignore` if the analyzer does not handle this type of block.
  """
  @callback analyze(block :: Prosody.block(), opts :: keyword()) ::
              {:ok, Prosody.analysis()} | :ignore | {:error, String.t()}

  @default_analyzers [Prosody.CodeAnalyzer, Prosody.TextAnalyzer]

  @doc """
  Analyze content blocks using configured analyzers. Returns `{:ok, result}` or
  `{:error, reason}`.

  Supports both single blocks and lists of blocks. For lists, applies analyzers to each
  block and collects the results.

  Options:

  - `:analyzers` (default: `:default`): List of analyzer modules that will be tried in
    order until one doesn't return `:ignore`. The analyzer modules may be provided as
    either the module itself (where it will be responsible for parsing out its options
    from the opts passed to `analyze/2` or as `{module, opts}`, where the options for the
    analyzer are isolated from other options.

    The analyzer module list may include `:default` as the last entry, which expands to
    `#{inspect(@default_analyzers)}`. If present, `:default` must be the *last* entry,
    because `Prosody.TextAnalyzer` will analyze any content block as if it were text.

  ## Examples

  ```elixir
  # Use default analyzers
  analyze(blocks)
  analyze(blocks, analyzers: :default)

  # Add custom analyzer before defaults
  analyze(blocks, analyzers: [MermaidAnalyzer, :default])

  # Use only custom analyzers
  analyze(blocks, analyzers: [{MyCodeAnalyzer, my_code_analyzer_opts}, MyTextAnalyzer])
  ```
  """
  @spec analyze(Prosody.block() | [Prosody.block()], keyword()) ::
          {:ok, [Prosody.analysis()]} | {:error, String.t()}
  def analyze(blocks, opts \\ []) do
    blocks = List.wrap(blocks)

    with {:ok, analyzers, opts} <- prepare_analyzers(opts) do
      process_blocks(blocks, analyzers, opts)
    end
  end

  @doc """
  Analyze content blocks using configured analyzers. Returns the result list or raises an
  error.

  Supports both single blocks and lists of blocks. For lists, applies analyzers to each
  block and collects the results.

  Options:

  - `:analyzers` (default: `:default`): List of analyzer modules that will be tried in
    order until one doesn't return `:ignore`. The analyzer modules may be provided as
    either the module itself (where it will be responsible for parsing out its options
    from the opts passed to `analyze/2` or as `{module, opts}`, where the options for the
    analyzer are isolated from other options.

    The analyzer module list may include `:default` as the last entry, which expands to
    `#{inspect(@default_analyzers)}`. If present, `:default` must be the *last* entry,
    because `Prosody.TextAnalyzer` will analyze any content block as if it were text.

  ## Examples

  ```elixir
  # Use default analyzers
  analyze!(blocks)
  analyze!(blocks, analyzers: :default)

  # Add custom analyzer before defaults
  analyze!(blocks, analyzers: [MermaidAnalyzer, :default])

  # Use only custom analyzers
  analyze!(blocks, analyzers: [MyCodeAnalyzer, MyTextAnalyzer])
  ```
  """
  @spec analyze!(Prosody.block() | [Prosody.block()], keyword()) :: [Prosody.analysis()]
  def analyze!(blocks, opts \\ []) do
    case analyze(blocks, opts) do
      {:ok, results} -> results
      {:error, reason} -> raise Prosody.Error, phase: :analyze, reason: reason
    end
  end

  defp process_blocks(blocks, analyzers, opts) do
    case Enum.reduce_while(blocks, [], &reduce_block(&1, &2, analyzers, opts)) do
      {:error, reason} -> {:error, reason}
      results -> {:ok, Enum.reverse(results)}
    end
  end

  defp prepare_analyzers(opts) do
    {analyzers, opts} = Keyword.pop(opts, :analyzers, :default)

    analyzers = List.wrap(analyzers)

    if List.last(analyzers) != :default and Enum.find(analyzers, &(&1 == :default)) do
      {:error, ":analyzers must have :default as the last value if present"}
    else
      analyzers =
        Enum.flat_map(analyzers, fn
          :default -> @default_analyzers
          analyzer -> List.wrap(analyzer)
        end)

      {:ok, analyzers, opts}
    end
  end

  defp reduce_block(block, results, analyzers, opts) do
    case try_analyzers(block, analyzers, opts) do
      {:ok, result} -> {:cont, [result | results]}
      {:error, reason} -> {:halt, {:error, reason}}
      :ignore -> {:cont, results}
    end
  end

  defp try_analyzers(_block, [], _opts) do
    {:error, "No analyzer handled the block"}
  end

  defp try_analyzers(block, [{analyzer, opts} | rest], _opts) do
    case analyzer.analyze(block, opts) do
      :ignore -> try_analyzers(block, rest, opts)
      result -> result
    end
  end

  defp try_analyzers(block, [analyzer | rest], opts) do
    case analyzer.analyze(block, opts) do
      :ignore -> try_analyzers(block, rest, opts)
      result -> result
    end
  end
end

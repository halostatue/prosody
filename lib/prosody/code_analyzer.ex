defmodule Prosody.CodeAnalyzer do
  @moduledoc """
  Code content analyzer with cognitive load adjustments for programming content.

  This analyzer processes code blocks and applies cognitive load multipliers to account
  for the mental overhead of context switching between prose and code. The algorithm
  handles identifier boundaries, numeric literals, and operator sequences appropriately.

  ## Algorithm

  1. **Line Processing**: Reject blank lines and count the remaining lines.

  2. **Token Splitting**: Split lines on whitespace and identifier boundaries, using
     heuristics to treat operators as countable tokens.

     - Decimal literals are treated as single tokens (`3.14` is one token)

     - Simple string literals (`"string"`, `'string'`, and `` `string` ``) are unwrapped
       for token counting; triple literals (`\"""`, `'''`, or `` ``` ``) are left alone

     - Dots between identifiers (`object.method.call`) are replaced with space for
       identifier tokenization (resulting in 3 tokens, not 5)

     - Non-identifier character sequences are treated as single tokens, so the Elixir range
       literal (`1..10//2`) is treated as 5 tokens

  3. **Cognitive Load**: Apply reading word adjustment based on token density

     - Lines with < 5 tokens: token count = reading words
     - Lines with ≥ 5 tokens: `max(tokens + 3, 10)` reading words

  There are no configuration options for `Prosody.CodeAnalyzer`.

  ### Examples

  #### Simple Function

  ```elixir
  block = %{
    type: :code,
    content: "def hello\\n  puts 'world'\\nend",
    language: "ruby"
  }

  # Line 1: "def hello" -> 2 tokens -> 2 reading words
  # Line 2: "  puts 'world'" -> 2 tokens -> 2 reading words
  # Line 3: "end" -> 1 token -> 1 reading word
  # Result: %{words: 5, reading_words: 5, lines: 3}
  ```

  #### Complex Expression

  ```elixir
  block = %{
    type: :code,
    content: "result = Math.sqrt(a * a + b * b)",
    language: "javascript"
  }

  # Tokens: ["result", "=", "Math", "sqrt", "(", "a", "*", "a", "+", "b", "*", "b", ")"]
  # 13 tokens -> max(13 + 3, 10) = 16 reading words
  # Result: %{words: 13, reading_words: 16, lines: 1}
  ```

  #### Numeric and Operator Handling

  ```elixir
  block = %{
    type: :code,
    content: "range = 1..100\\nstep = 3.14159",
    language: "ruby"
  }

  # Line 1: ["range", "=", "1", "..", "100"] -> 5 tokens -> max(5 + 3, 10) = 10 reading words
  # Line 2: ["step", "=", "3.14159"] -> 3 tokens -> 3 reading words
  # Result: %{words: 8, reading_words: 13, lines: 2}
  ```
  """

  @behaviour Prosody.Analyzer

  @impl Prosody.Analyzer
  def analyze(%{type: :code} = block, _opts) do
    {actual_words, reading_words, code_lines} =
      block.content
      |> String.split()
      |> Enum.reduce({0, 0, 0}, &analyze_line/2)

    {:ok,
     %{
       words: actual_words,
       reading_words: reading_words,
       lines: code_lines,
       metadata: %{
         type: :code,
         language: Map.get(block, :language),
         parser_metadata: Map.get(block, :metadata, %{})
       }
     }}
  end

  def analyze(%{type: _}, _opts), do: :ignore

  defp analyze_line(line, {words, reading, lines} = acc) do
    if String.trim(line) == "" do
      acc
    else
      tokens = tokenize_line(line)
      actual = length(tokens)
      load = if actual < 5, do: actual, else: max(actual + 3, 10)
      {words + actual, reading + load, lines + 1}
    end
  end

  defp tokenize_line(line) do
    line
    |> unwrap_string_literals()
    |> preserve_numeric_literals()
    |> split_dotted_references()
    |> String.split(~r/\s+/, trim: true)
    |> split_tokens()
    |> Enum.reject(&(&1 == ""))
  end

  defp unwrap_string_literals(line) do
    line
    |> String.replace(~r/"(?!"")((?:[^"\\]|\\.)*)"/, " \\1 ")
    |> String.replace(~r/'(?!'')((?:[^'\\]|\\.)*)'/, " \\1 ")
    |> String.replace(~r/`(?!``)((?:[^`\\]|\\.)*)`/, " \\1 ")
  end

  defp preserve_numeric_literals(line) do
    String.replace(line, ~r/-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/, "N")
  end

  defp split_dotted_references(line) do
    String.replace(line, ~r/(\w)\.(\w)/, "\\1 \\2")
  end

  defp split_tokens(tokens) when is_list(tokens) do
    Enum.flat_map(tokens, &split_identifiers/1)
  end

  defp split_identifiers(token) do
    token
    |> String.replace(~r/([^\w\s]+)/, " OP ")
    |> String.split(~r/\s+/, trim: true)
  end
end

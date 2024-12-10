defmodule Prosody.AnalyzerTest do
  use ExUnit.Case, async: true

  alias Prosody.Analyzer

  defmodule MockAnalyzer do
    @behaviour Analyzer

    def analyze(%{type: :code}, _opts), do: {:ok, %{words: 5, reading_words: 5, lines: 1}}
    def analyze(%{type: _}, _opts), do: :ignore
  end

  describe ":default token expansion" do
    @text %{type: :text, content: "Hello world", language: nil, metadata: %{}}
    @code %{type: :code, content: "Hello world", language: nil, metadata: %{}}

    test "expands :default to default analyzers" do
      assert Analyzer.analyze(@text, analyzers: :default, debug: true) ==
               Analyzer.analyze(@text, analyzers: [Prosody.CodeAnalyzer, Prosody.TextAnalyzer], debug: true)

      assert Analyzer.analyze(@code, analyzers: :default, debug: true) ==
               Analyzer.analyze(@code, analyzers: [Prosody.CodeAnalyzer, Prosody.TextAnalyzer], debug: true)
    end

    test "expands :default in analyzer list" do
      assert {:ok, [%{words: 2, metadata: %{type: :text}}]} =
               Analyzer.analyze(@text, analyzers: [MockAnalyzer, :default])

      assert {:ok, [%{words: 5, lines: 1, reading_words: 5}]} ==
               Analyzer.analyze(@code, analyzers: [MockAnalyzer, :default])
    end
  end
end

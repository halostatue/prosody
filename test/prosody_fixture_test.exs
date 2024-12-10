defmodule Prosody.FixtureTests do
  use ExUnit.Case, async: true

  @fixtures_dir "test/support/fixtures"

  @text_fixtures %{
    "en" => %{
      "a_modest_proposal.md" => %{minimal: 3400, maximal: 3431, balanced: 3410},
      "alices_adventures_in_wonderland.md" => %{minimal: 26_382, maximal: 26_711, balanced: 26_525},
      "frankenstein.md" => %{minimal: 74_959, maximal: 75_206, balanced: 75_081},
      "the_adventure_of_the_three_students.md" => %{minimal: 6485, maximal: 6566, balanced: 6541},
      "the_black_cat.md" => %{minimal: 3875, maximal: 3985, balanced: 3963},
      "the_pit_and_the_pendulum.md" => %{minimal: 6086, maximal: 6216, balanced: 6192},
      "the_time_machine.md" => %{minimal: 32_327, maximal: 32_710, balanced: 32_520}
    }
  }

  describe "text fixture analysis" do
    for {language, fixtures} <- @text_fixtures, {fixture, variants} <- fixtures, {algorithm, expected} <- variants do
      content = File.read!(Path.join([@fixtures_dir, language, fixture]))

      test "#{language}/#{fixture} with algorithm #{inspect(algorithm)}" do
        assert {:ok, result} =
                 Prosody.TextAnalyzer.analyze(
                   %{type: :text, content: unquote(content), language: unquote(language), metadata: %{}},
                   algorithm: unquote(algorithm),
                   debug: true
                 )

        assert result.words == unquote(expected)
      end
    end
  end

  @code_fixtures %{
    "cpp" => %{
      file: "bubble_sort.cpp",
      expected: %{code: %{lines: 641}, reading_time: 7, text: nil, words: 1253}
    },
    "elixir" => %{
      file: "bubble_sort.ex",
      expected: %{code: %{lines: 393, words: 644}, reading_time: 4, text: nil, words: 644}
    },
    "python" => %{
      file: "bubble_sort.py",
      expected: %{code: %{lines: 546}, reading_time: 6, text: nil, words: 1135}
    },
    "rust" => %{
      file: "bubble_sort.rs",
      expected: %{code: %{lines: 140}, reading_time: 2, text: nil, words: 296}
    },
    "go" => %{
      file: "bubblesort.go",
      expected: %{code: %{lines: 68, words: 146}, reading_time: 1, text: nil, words: 146}
    },
    "zig" => %{
      file: "bubbleSort.zig",
      expected: %{code: %{lines: 286}, reading_time: 3, words: 522}
    }
  }

  describe "code fixture analysis" do
    for {language, %{file: file, expected: expected}} <- @code_fixtures do
      content = File.read!(Path.join([@fixtures_dir, "code", file]))
      expected = Macro.escape(expected)

      content = """
      ```#{language}
      #{content}
      ```
      """

      test "analyzes #{language}/#{file} in a markdown block" do
        assert {:ok, unquote(expected)} = Prosody.analyze(unquote(content), parser: :markdown)
      end
    end
  end
end

defmodule Prosody.SummarizationTest do
  use ExUnit.Case, async: true

  describe "summarize/2" do
    test "aggregates text-only analysis results" do
      analysis = [text(50), text(30), text(20)]

      assert {:ok, %{words: 100, reading_time: 1, code: nil, text: %{words: 100}}} =
               Prosody.summarize(analysis, words_per_minute: 500, min_reading_time: 1)
    end

    test "aggregates mixed text and code analysis results" do
      analysis = [text(50), code(40, 3), text(30)]

      assert {:ok,
              %{
                words: 120,
                reading_time: 1,
                text: %{words: 80},
                code: %{words: 40, lines: 3}
              }} = Prosody.summarize(analysis, words_per_minute: 200, min_reading_time: 1)
    end

    test "calculates reading time correctly with different words per minute" do
      analysis = [text(400)]

      assert {:ok, %{reading_time: 2}} = Prosody.summarize(analysis, words_per_minute: 200, min_reading_time: 1)

      assert {:ok, %{reading_time: 4}} = Prosody.summarize(analysis, words_per_minute: 100, min_reading_time: 1)

      assert {:ok, %{reading_time: 1}} = Prosody.summarize(analysis, words_per_minute: 500, min_reading_time: 1)
    end

    test "respects minimum reading time threshold" do
      analysis = [text(100)]

      # Below minimum - should return the minimum
      assert {:ok, %{reading_time: 2}} = Prosody.summarize(analysis, words_per_minute: 200, min_reading_time: 2)

      # At minimum - should return the time
      assert {:ok, %{reading_time: 1}} = Prosody.summarize(analysis, words_per_minute: 100, min_reading_time: 1)

      # Above minimum - should return the time
      assert {:ok, %{reading_time: 2}} = Prosody.summarize(analysis, words_per_minute: 50, min_reading_time: 1)
    end

    test "handles code complexity in reading time calculations" do
      analysis = [text(100), code(80, 5)]

      assert {:ok,
              %{
                words: 180,
                reading_time: 1,
                text: %{words: 100},
                code: %{words: 80, lines: 5}
              }} = Prosody.summarize(analysis, words_per_minute: 200, min_reading_time: 1)
    end

    test "handles empty analysis results" do
      assert {:ok, %{words: 0, reading_time: 1, text: nil, code: nil}} =
               Prosody.summarize([], words_per_minute: 200, min_reading_time: 1)
    end

    test "handles single analysis result" do
      analysis = text(150)

      assert {:ok, %{words: 150, reading_time: 1, code: nil}} =
               Prosody.summarize(analysis, words_per_minute: 200, min_reading_time: 1)
    end

    test "uses default options when not specified" do
      analysis = [text(200)]

      assert {:ok, %{words: 200, reading_time: 1, code: nil}} = Prosody.summarize(analysis)
    end

    test "validates words_per_minute option" do
      analysis = [text(100)]

      assert {:error, message} = Prosody.summarize(analysis, words_per_minute: 0)
      assert message =~ "invalid :words_per_minute value"

      assert {:error, message} = Prosody.summarize(analysis, words_per_minute: -100)
      assert message =~ "invalid :words_per_minute value"

      assert {:error, message} = Prosody.summarize(analysis, words_per_minute: "invalid")
      assert message =~ "invalid :words_per_minute value"
    end

    test "validates min_reading_time option" do
      analysis = [text(100)]

      assert {:error, message} = Prosody.summarize(analysis, min_reading_time: -1)
      assert message =~ "invalid :min_reading_time value"

      assert {:error, message} = Prosody.summarize(analysis, min_reading_time: "invalid")
      assert message =~ "invalid :min_reading_time value"

      # Zero should be valid
      assert {:ok, %{code: nil, reading_time: 1, text: %{words: 100}, words: 100}} =
               Prosody.summarize(analysis, min_reading_time: 0)
    end
  end

  describe "summarize!/2" do
    test "returns result directly on success" do
      assert %{words: 100, reading_time: 1, code: nil} =
               Prosody.summarize!([text(100)], words_per_minute: 200, min_reading_time: 1)
    end

    test "raises on validation error" do
      assert_raise Prosody.Error, ~r/invalid :words_per_minute value/, fn ->
        Prosody.summarize!(text(100), words_per_minute: 0)
      end
    end
  end

  defp text(words) do
    %{words: words, reading_words: words, metadata: %{type: :text}}
  end

  defp code(words, lines) do
    %{words: floor(words * 0.9), reading_words: words, lines: lines, metadata: %{type: :code}}
  end
end

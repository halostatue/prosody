defmodule Prosody.TextAnalyzerTest do
  use ExUnit.Case, async: true

  alias Prosody.TextAnalyzer

  describe "algorithm comparison with complex content" do
    @block %{
      type: :text,
      content:
        "The CEO's Q3 buy/sell analysis shows revenue increased 23.8% year-over-year, reaching $4.2M through our e-commerce platform at shop.company.co.uk. Email investors@company.com for the full profit/loss report.",
      language: nil,
      metadata: %{}
    }

    test "minimal" do
      assert {:ok, result} = TextAnalyzer.analyze(@block, algorithm: :minimal, debug: true)
      assert result.words == 25

      assert result.metadata.debug.words == [
               "The",
               "CONTRACTION",
               "Q3",
               "buy/sell",
               "analysis",
               "shows",
               "revenue",
               "increased",
               "NUMBER%",
               "year-over-year,",
               "reaching",
               "$4.2M",
               "through",
               "our",
               "e-commerce",
               "platform",
               "at",
               "shop.company.co.uk.",
               "Email",
               "EMAIL",
               "for",
               "the",
               "full",
               "profit/loss",
               "report."
             ]
    end

    test "balanced" do
      assert {:ok, result} = TextAnalyzer.analyze(@block, algorithm: :balanced, debug: true)
      assert result.words == 30

      assert result.metadata.debug.words == [
               "The",
               "CONTRACTION",
               "Q3",
               "buy",
               "sell",
               "analysis",
               "shows",
               "revenue",
               "increased",
               "NUMBER%",
               "year",
               "over",
               "year,",
               "reaching",
               "$4.2M",
               "through",
               "our",
               "e",
               "commerce",
               "platform",
               "at",
               "shop.company.co.uk.",
               "Email",
               "EMAIL",
               "for",
               "the",
               "full",
               "profit",
               "loss",
               "report."
             ]
    end

    test "maximal" do
      assert {:ok, result} = TextAnalyzer.analyze(@block, algorithm: :maximal, debug: true)
      assert result.words == 37

      assert result.metadata.debug.words == [
               "The",
               "CONTRACTION",
               "Q3",
               "buy",
               "sell",
               "analysis",
               "shows",
               "revenue",
               "increased",
               "23",
               "8",
               "year",
               "over",
               "year",
               "reaching",
               "4",
               "2M",
               "through",
               "our",
               "e",
               "commerce",
               "platform",
               "at",
               "shop",
               "company",
               "co",
               "uk",
               "Email",
               "investors",
               "company",
               "com",
               "for",
               "the",
               "full",
               "profit",
               "loss",
               "report"
             ]
    end
  end
end

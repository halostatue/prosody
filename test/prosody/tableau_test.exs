defmodule Prosody.TableauTest do
  use ExUnit.Case, async: true

  alias Prosody.Tableau, as: Extension

  # Mock a parser that fails
  defmodule FailingParser do
    @moduledoc false
    def parse(_, _), do: {:error, "parse failed"}
  end

  describe "config/1" do
    test "basic configuration works" do
      assert {:ok, %{enabled: true, parsers: %{".md" => Extension.MDExParser, :default => Prosody.TextParser}}} =
               Extension.config(%{enabled: true})
    end

    test "rejects unknown options" do
      assert {:error, message} = Extension.config(%{bogus_option: true})
      assert message =~ "Unknown configuration option bogus_option"
    end

    test "handles algorithm configuration with validation" do
      assert {:ok, %{analysis_opts: [algorithm: :balanced]}} = Extension.config(%{algorithm: :balanced})
      assert {:ok, %{analysis_opts: [algorithm: :minimal]}} = Extension.config(%{algorithm: :minimal})
      assert {:ok, %{analysis_opts: [algorithm: :maximal]}} = Extension.config(%{algorithm: :maximal})
      assert {:error, message} = Extension.config(%{algorithm: :invalid})
      assert message =~ "invalid :algorithm value"
    end

    test "handles boolean analysis options with validation" do
      assert {:ok, %{analysis_opts: opts}} =
               Extension.config(%{preserve_urls: true, preserve_emails: false})

      assert opts[:preserve_emails] == false
      assert opts[:preserve_urls] == true

      assert {:error, message} = Extension.config(%{preserve_urls: "invalid"})
      assert message =~ "invalid boolean :preserve_urls value"
    end

    test "handles word separators with validation" do
      assert {:ok, %{analysis_opts: [word_separators: %Regex{}]}} = Extension.config(%{word_separators: ~r/\s+/})
      assert {:ok, %{analysis_opts: [word_separators: %Regex{}]}} = Extension.config(%{word_separators: "\\s+"})
      assert {:ok, %{analysis_opts: [word_separators: {:ac, _}]}} = Extension.config(%{word_separators: [" ", "\t"]})
      assert {:error, message} = Extension.config(%{word_separators: 123})
      assert message =~ "invalid word separators"
    end

    test "handles words per minute with validation" do
      assert {:ok, %{summarize_opts: [words_per_minute: 250]}} = Extension.config(%{words_per_minute: 250})
      assert {:error, message} = Extension.config(%{words_per_minute: 0})
      assert message =~ "invalid :words_per_minute value"

      assert {:error, message} = Extension.config(%{words_per_minute: -10})
      assert message =~ "invalid :words_per_minute value"
    end

    test "handles min reading time with validation" do
      assert {:ok, %{summarize_opts: [min_reading_time: 1]}} = Extension.config(%{min_reading_time: 1})
      assert {:ok, %{summarize_opts: [min_reading_time: 0]}} = Extension.config(%{min_reading_time: 0})
      assert {:error, message} = Extension.config(%{min_reading_time: -1})
      assert message =~ "invalid :min_reading_time value"
    end

    test "handles custom parsers" do
      assert {:ok,
              %{
                parsers: %{".txt" => CustomParser, ".json" => AnotherParser},
                parser_opts: %{
                  CustomParser => [strip_frontmatter: false, custom_opt: true],
                  AnotherParser => [strip_frontmatter: false]
                }
              }} =
               Extension.config(%{parsers: [txt: {CustomParser, custom_opt: true}, json: AnotherParser]})
    end

    test "handles analyzers option with validation" do
      assert {:ok, %{analysis_opts: [analyzers: [:text, :code]]}} = Extension.config(%{analyzers: [:text, :code]})
      assert {:error, error} = Extension.config(%{analyzers: "invalid"})
      assert error =~ "Invalid `:analyzers` option"
    end
  end

  describe "pre_build/1" do
    test "processes posts with prosody analysis" do
      {%{body: body}, token} = build_post("test.md", "# Test\n\nContent")
      assert {:ok, %{posts: [%{body: ^body, prosody: %{}}]}} = Extension.pre_build(token)
    end

    test "skips posts with prosody: false" do
      {_post, token} = build_post("test.md", "Content", frontmatter: %{prosody: false})
      assert {:ok, %{posts: [%{prosody: false}]}} = Extension.pre_build(token)
    end

    test "skips posts without file" do
      {post, token} = build_post(nil, "Content")
      assert {:ok, %{posts: [^post]}} = Extension.pre_build(token)
    end

    test "handles posts with no matching parser" do
      {%{body: body}, token} = build_post("test.unknown", "Content")
      assert {:ok, %{posts: [%{body: ^body, prosody: %{}}]}} = Extension.pre_build(token)
    end

    test "handles parser errors gracefully" do
      {_post, token} = build_post("test.md", "Content", parsers: [md: FailingParser])
      assert {:ok, %{posts: [%{prosody: %{error: "parse failed"}}]}} = Extension.pre_build(token)
    end
  end

  describe "MDExParser" do
    @content "# Test\n\n~~Content~~"

    {:ok, config} = Tableau.Config.new(%{url: "http://localhost/"})

    @site_blank config

    {:ok, config} =
      Tableau.Config.new(%{
        url: "http://localhost/",
        markdown: [mdex: [extension: [strikethrough: true]]]
      })

    @site_strikethrough config

    test "parses markdown content" do
      assert {:ok, [%{content: "Test"}, %{content: "~~Content~~"}]} = Extension.MDExParser.parse(@content)
    end

    test "uses site config when provided" do
      assert {:ok, [%{content: "Test"}, %{content: "Content"}]} =
               Extension.MDExParser.parse(@content, site: @site_strikethrough)

      assert {:ok, [%{content: "Test"}, %{content: "~~Content~~"}]} =
               Extension.MDExParser.parse(@content, site: @site_blank)
    end

    test "handles missing site config" do
      assert {:ok, [%{content: "Test"}, %{content: "~~Content~~"}]} = Extension.MDExParser.parse(@content, [])
    end

    test "merges site config with opts" do
      assert {:ok, [%{content: "Test"}, %{content: "Content"}]} =
               Extension.MDExParser.parse(@content, site: @site_strikethrough, strip_frontmatter: true)
    end
  end

  defp build_post(file, body, opts \\ []) do
    {frontmatter, opts} = Keyword.pop(opts, :frontmatter)
    {site, opts} = Keyword.pop(opts, :site, %Tableau.Config{})

    post =
      %{file: file, body: body}
      |> then(&if frontmatter, do: Map.merge(&1, frontmatter), else: &1)
      |> then(&if file, do: &1, else: Map.delete(&1, :file))

    case Extension.config(opts) do
      {:ok, config} ->
        token = %{
          posts: [post],
          extensions: %{prosody: %{config: config}},
          site: %{config: site}
        }

        {post, token}

      {:error, reason} ->
        refute reason
    end
  end
end

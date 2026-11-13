# Prosody Usage Rules

Prosody analyzes reading flow and cognitive load for mixed text and code
content as found in technical blogs. Provides extensible content analysis with
built-in support for Markdown and Tableau integration.

## Core Principles

1. **Configurable content analysis** - Combine multiple analyzers for
   comprehensive metrics tailored to your content
2. **Tableau integration** - First-class Tableau support
3. **Markup-aware parsing** - Separate text from markup to analyze content
   accurately
4. **Content-type differentiation** - Code and text analyzed with different
   strategies

## Usage Modes

### 1. Tableau Extension

Automatic analysis of posts during site generation.

```elixir
# config/config.exs
config :tableau, Prosody.Tableau,
  enabled: true,
  parsers: :default,
  words_per_minute: 200,
  min_reading_time: 1
```

Configuration options:

- `:enabled` (default `false`) - Enable/disable the extension
- `:parsers` (default `:default`) - Parser configuration by file extension
  - `:default` alone or in list adds Markdown handling with
    `Prosody.Tableau.MDExParser` (which reads MDEx configuration from Tableau)
    and a `Prosody.TextParser` fallback for unmatched extensions
  - Keyword list like `[md: Prosody.Tableau.MDExParser, dj: MyDjotParser]`
  - Parsers may be `module` or `{module, opts}`
  - Use `default: MyParser` for unmatched extensions; without a `:default`
    entry, unmatched content is skipped
- `:analyzers` - List of analyzer modules (default
  `[Prosody.CodeAnalyzer, Prosody.TextAnalyzer]`)
- `:words_per_minute` (default `200`) - Reading speed for time estimation
- `:min_reading_time` (default `1`) - Minimum reading time in minutes
- `:algorithm`, `:skip_punctuation_words`, `:preserve_urls`,
  `:preserve_emails`, `:preserve_numbers`, `:word_separators` - Passed to
  `Prosody.TextAnalyzer` (see [Text Analyzer](#text-analyzer))

### 2. Programmatic API

For custom integrations or standalone analysis.

```elixir
# Parse content (parser defaults to :text)
{:ok, blocks} = Prosody.parse(content, parser: :markdown)
{:ok, blocks} = Prosody.parse(content, parser: {:markdown, strip_frontmatter: false})

# Analyze blocks
{:ok, analysis} = Prosody.analyze_blocks(blocks)

# Summarize results
{:ok, summary} = Prosody.summarize(analysis, words_per_minute: 200)

# Or do it all at once
{:ok, summary} = Prosody.analyze(content, parser: :markdown)

# Access metrics
summary.reading_time  # minutes
summary.words         # total reading words
summary.text.words    # text-only word count
summary.code.words    # code-only word count
summary.code.lines    # code line count
```

### 3. Custom Parsers

Implement `Prosody.Parser` for other content formats.

```elixir
defmodule MyApp.CustomParser do
  @behaviour Prosody.Parser

  @impl true
  def parse(content, _opts) do
    # Return {:ok, [blocks]} or {:error, reason}
    # Each block is a map with keys:
    #   type: :text | :code
    #   content: string
    #   language: nil | string
    #   metadata: map
  end
end

# Use custom parser
{:ok, blocks} = Prosody.parse(content, parser: MyApp.CustomParser)
```

## Decision Guide: When to Use What

### Choose Your Parser

**Use `Prosody.MDExParser` (`:markdown`) when:**

- Content is Markdown
- MDEx is available in dependencies
- You want fast, CommonMark-compliant parsing

**Use `Prosody.Tableau.MDExParser` when:**

- Configuring Markdown parsing for the Tableau extension
- MDEx options should match the Tableau site configuration

**Use `Prosody.TextParser` when:**

- Content is plain text
- No markup to parse
- Simple word counting needed

**Use custom parser when:**

- Content is not Markdown or plain text
- Special parsing requirements
- Integration with existing parsing pipeline

### Choose Your Analyzers

**Use `Prosody.CodeAnalyzer` when:**

- Analyzing code blocks
- Tokenizing code for cognitive load estimation
- Language-specific analysis needed

**Use `Prosody.TextAnalyzer` when:**

- Analyzing prose content
- Word counting with various strategies
- Filtering punctuation or preserving special patterns

**Use both (default) when:**

- Content mixes text and code (technical blogs)
- You want comprehensive analysis
- Separate metrics for code vs text needed

## Common Configuration Patterns

### Minimal Tableau Setup

```elixir
# Just enable with defaults (Markdown + text fallback)
config :tableau, Prosody.Tableau, enabled: true
```

### Custom Reading Speed

```elixir
config :tableau, Prosody.Tableau,
  enabled: true,
  words_per_minute: 250,
  min_reading_time: 2
```

### Custom Analyzer Selection

```elixir
config :tableau, Prosody.Tableau,
  enabled: true,
  analyzers: [Prosody.TextAnalyzer]  # Text only, skip code analysis
```

### Text Analysis Options

```elixir
config :tableau, Prosody.Tableau,
  enabled: true,
  algorithm: :balanced,              # or :minimal, :maximal
  skip_punctuation_words: true,
  preserve_urls: true,
  preserve_emails: true,
  preserve_numbers: true
```

### Standalone Analysis

```elixir
defmodule MyApp.ContentAnalyzer do
  def analyze_post(content) do
    Prosody.analyze(content,
      parser: :markdown,
      words_per_minute: 200
    )
  end
end
```

## Built-in Analyzers

### Code Analyzer

Analyzes code blocks by tokenizing and estimating cognitive load.

```elixir
# Block analysis result
%{
  words: 45,
  reading_words: 90,  # Adjusted for cognitive load
  lines: 12,
  metadata: %{
    type: :code,
    language: "elixir",
    parser_metadata: %{}
  }
}
```

Features:

- Tokenizes code into identifiers and operators
- Splits dotted references and camelCase
- Preserves numeric literals
- Unwraps string literals for content analysis
- Estimates cognitive load per line

### Text Analyzer

Analyzes prose content with configurable word counting strategies.

```elixir
# Block analysis result
%{
  words: 150,
  reading_words: 150,
  metadata: %{
    type: :text,
    parser_metadata: %{}
  }
}
```

Configuration options:

- `:algorithm` - Word counting strategy: `:balanced` (default), `:minimal`,
  `:maximal`
- `:skip_punctuation_words` - Exclude punctuation-only words
- `:preserve_urls` - Keep URLs as single tokens
- `:preserve_emails` - Keep emails as single tokens
- `:preserve_numbers` - Keep numbers as single tokens
- `:word_separators` - Custom regex or list for splitting; cannot be combined
  with `:algorithm`

Each algorithm sets its own defaults for the other options, which may be
overridden individually (e.g., `algorithm: :maximal, preserve_urls: true`):

- `:balanced` (default) - Splits on whitespace, `-`, and `/`; preserves URLs,
  emails, and numbers; skips punctuation-only words
- `:minimal` - Splits on whitespace only; preserves URLs, emails, and numbers;
  skips punctuation-only words
- `:maximal` - Splits on whitespace and punctuation; does not preserve URLs,
  emails, or numbers; skips punctuation-only words

## Tableau Integration Details

### Post Frontmatter

Analysis results are added to post frontmatter:

```yaml
---
title: "My Technical Post"
prosody:
  reading_time: 8
  words: 1500
  text:
    words: 1200
  code:
    words: 300
    lines: 45
---
```

### Template Access

Access metrics in templates:

```heex
<article>
  <header>
    <h1><%= @post.title %></h1>
    <p>Reading time: <%= @post.prosody.reading_time %> minutes</p>
    <p>Words: <%= @post.prosody.words %></p>
  </header>
  <%= @post.body %>
</article>
```

### Conditional Rendering

```heex
<%= if @post.prosody.code do %>
  <div class="code-heavy-notice">
    Contains <%= @post.prosody.code.lines %> lines of code
  </div>
<% end %>
```

### Disabling Per-Post

```yaml
---
title: "Skip Analysis"
prosody: false
---
```

## Custom Analyzers

Implement `Prosody.Analyzer` behaviour:

```elixir
defmodule MyApp.CustomAnalyzer do
  @behaviour Prosody.Analyzer

  @impl true
  def analyze(block, opts) do
    # Return {:ok, analysis}, :ignore, or {:error, reason}
    {:ok,
     %{
       words: count_words(block.content),
       reading_words: estimate_reading_words(block.content),
       metadata: %{type: :custom}
     }}
  end
end

# Use in configuration
config :tableau, Prosody.Tableau,
  enabled: true,
  analyzers: [
    Prosody.CodeAnalyzer,
    Prosody.TextAnalyzer,
    MyApp.CustomAnalyzer
  ]
```

Analyzer contract:

- Analyzers are tried in order until one returns something other than
  `:ignore`
- Return `:ignore` to skip the block
- Return `{:ok, map}` with `:words`, `:reading_words`, `:metadata` keys
- Optional `:lines` key for line count
- Metadata should include `:type` for categorization

## Configuration Options

Tableau extension options are listed under
[Tableau Extension](#1-tableau-extension) and text analyzer options under
[Text Analyzer](#text-analyzer).

### Parser Options

Passed to `Prosody.parse/2`:

- `:parser` (default `:text`) - `:markdown`, `:text`, a parser module, or
  `{parser, opts}`
- `:strip_frontmatter` - Remove YAML frontmatter (default varies by parser)
- Additional options depend on parser implementation; when the parser is given
  as `{parser, opts}`, only those `opts` are passed to it

### Summarize Options

- `:words_per_minute` (default `200`) - Reading speed for time calculation
- `:min_reading_time` (default `1`) - Minimum reading time in minutes

## Common Gotchas

1. **MDEx dependency** - `Prosody.MDExParser` requires MDEx in dependencies
   and is only available when MDEx is present.

2. **Tableau dependency** - `Prosody.Tableau` requires Tableau in dependencies
   and is only available when Tableau is present.

3. **Analyzer order** - Analyzers run in order specified. First matching
   analyzer handles each block (returns non-`:ignore` result).

4. **Reading words vs words** - `reading_words` includes cognitive load
   adjustments for code. `words` is the raw count.

5. **Block-level analysis** - Analyzers work on individual blocks (paragraphs,
   code blocks), not entire documents. Summarization aggregates results.

6. **Parser file extension mapping** - Tableau extension uses file extension
   to select parser. Configure `:parsers` option with extension keys.

7. **Markdown parser in Tableau** - When configuring Markdown explicitly in
   `:parsers`, use `Prosody.Tableau.MDExParser`, not `Prosody.MDExParser`. The
   plain parser does not read MDEx configuration from Tableau, so enabled
   extensions (e.g., strikethrough) may not match how the site renders posts.

8. **Frontmatter conflicts** - If post already has `:prosody` key in
   frontmatter, it will be overwritten unless set to `false` to disable
   analysis.

## Resources

- **[Hex Package](https://hex.pm/packages/prosody)** - Package on Hex.pm
- **[HexDocs](https://hexdocs.pm/prosody)** - Complete API documentation
- **[GitHub Repository](https://github.com/halostatue/prosody)** - Source code
- **[Tableau](https://hex.pm/packages/tableau)** - Static site generator
- **[MDEx](https://hex.pm/packages/mdex)** - Markdown parser

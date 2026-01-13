# Prosody

[![Hex.pm][shield-hex]][hexpm] [![Hex Docs][shield-docs]][docs]
[![Apache 2.0][shield-licence]][licence] ![Coveralls][shield-coveralls]

- code :: <https://github.com/halostatue/prosody>
- issues :: <https://github.com/halostatue/prosody/issues>

Prosody is an extensible content analysis library that measures reading flow and
cognitive load for mixed text and code content as would be found in a technical
blog.

For users of [Tableau][tableau], Prosody provides an extension
(`Prosody.Tableau`) which processes [posts][posts] and adds analysis results to
post frontmatter.

## Installation

Prosody can be installed by adding `prosody` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:prosody, "~> 1.0"}
  ]
end
```

`Prosody.MDExParser` is only available when [MDEx][mdex] is present in your
dependencies, and `Prosody.Tableau` is only available when [Tableau][tableau] is
present in your dependencies.

Prosody documentation is found on [HexDocs][docs].

## Semantic Versioning

Prosody follows [Semantic Versioning 2.0][semver].

[docs]: https://hexdocs.pm/prosody
[hexpm]: https://hex.pm/packages/prosody
[licence]: https://github.com/halostatue/prosody/blob/main/LICENCE.md
[mdex]: https://hex.pm/packages/mdex
[posts]: https://hexdocs.pm/tableau/Tableau.PostExtension.html
[semver]: https://semver.org/
[shield-coveralls]: https://img.shields.io/coverallsCoverage/github/halostatue/prosody?style=for-the-badge
[shield-docs]: https://img.shields.io/badge/hex-docs-lightgreen.svg?style=for-the-badge "Hex Docs"
[shield-hex]: https://img.shields.io/hexpm/v/prosody?style=for-the-badge "Hex Version"
[shield-licence]: https://img.shields.io/hexpm/l/prosody?style=for-the-badge&label=licence "Apache 2.0"
[tableau]: https://hex.pm/packages/tableau

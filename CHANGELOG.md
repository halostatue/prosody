# Prosody Changelog

## 1.2.0 / 2026-11-12

This change was prepared with the assistance of [Kiro][kiro].

- Prepared for [tableau#193][tableau-193]. This changes Tableau from having a
  Converter behaviour to using a converter extension
  (`Tableau.MDExExtension`). This checks for the configuration there,
  otherwise it tries to get the configuration from the location _before_ the
  change.

  In the unlikely event that _both_ exist, the newer configuration option take
  precedence.

- Fixed a bug in `Prosody.Tableau` config parsing. The documentation indicates
  that the configuration `[md: {mod, a: 1}, markdown: {mod, a: 2}]` should
  pass the options to the same module differently based on the extension. It
  did not, resulting in the last options winning or even being removed
  (`[md: {mod, a: 1}, markdown: mod]` would remove the `a: 1` options for `md`
  parsing). This has been fixed and the distinct options will be passed
  appropriately.

- Removed an unnecessary `require Integer` in a test.

- Updated the usage rules.

- Added my new [AI Policy](AI_POLICY.md).

## 1.1.0 / 2026-01-26

- Upgraded to Tableau 0.30 and MDEx 0.11.1 or higher so that native MDEx
  plugin support is used.

- Added [usage rules](./usage-rules.md) for use with [`usage_rules`][urules].

  The usage rules were built with the assistance of [Kiro][kiro].

## 1.0.1 / 2026-01-12

- Fix an error with Prosody.Tableau where Tableau configuration wasn't being
  retrieved properly if not provided. This was mostly a testing failure (the
  tests did not properly emulate a Tableau environment).

- Fixed a few issues in various support documents, including simplifying the
  security policy.

## 1.0.0 / 2026-01-06

- Initial release.

[kiro]: https://kiro.dev
[tableau-193]: https://github.com/elixir-tools/tableau/pull/193
[urules]: https://github.com/ash-project/usage_rules

# Prosody Changelog

## 1.1.0 / 2026-01-26

- Upgraded to Tableau 0.30 and MDEx 0.11.1 or higher so that native MDEx plugin
  support is used.

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
[urules]: https://github.com/ash-project/usage_rules

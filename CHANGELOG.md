# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] - 2026-06-23

### Added

- `multicite` now accepts a content body with `@key` references: `#multicite[@smith2020 @jones2021]`. Supports supplements via `@key[p. 42]` syntax. The existing string/dict API remains fully supported. ([#2](https://github.com/pku-typst/citeproc-typst/issues/2))
- `nocite` function for including bibliography entries without citing them in-text. Supports `#nocite[@key1 @key2]`, `#nocite("key1", "key2")`, and `#nocite("*")` for all entries. ([#3](https://github.com/pku-typst/citeproc-typst/issues/3))
- CSL-JSON inline markup support for citeproc-js-compatible HTML-ish tags, including `<i>`, `<b>`, `<sc>`, `<sup>`, `<sub>`, and supported `<span>` variants such as `nocase`, `nodecor`, and `font-variant: small-caps`.

### Changed

- Improved CSL test-suite compatibility for inline markup fixtures; the documented exclusion set is reduced to 70 tests.

### Fixed

- Fixed author-date collapse behavior so author groups are merged only when adjacent, and year suffixes are not duplicated across collapsed groups.
- Fixed authored Chinese typographic quotation marks being converted to angle brackets such as `》`; authored typographic quotes are now preserved while straight ASCII quotes are still normalized where CSL quote handling applies. ([#5](https://github.com/pku-typst/citeproc-typst/issues/5))
- Fixed compiler runtime handling of `year-suffix` when issued dates are missing or rendered through fallback date branches.
- Fixed inline markup rendering so layout-level formatting is preserved when HTML-ish CSL-JSON tags are present.

### Performance

- Hoisted frequently used regular expressions out of hot loops.
- Reduced duplicate parsing on inline markup paths by reusing parsed inline nodes for plain-text checks.

## [0.2.0] - 2026-02-07

### Added

- CSL test-suite compliance: 758/845 standard tests pass; the remaining 87 are explicitly excluded with documented reasons (spec interpretation differences from citeproc-js, HTML-specific features, etc.)
- Experimental CSL-to-Typst compiler that compiles CSL macros into native Typst functions via `eval()`, eliminating interpreter overhead. Enable with `--input compiler=true`

### Fixed

- Fix extra brackets appearing in citations with page locators (e.g., `@key[p. 42]` now renders correctly as `[1, p. 42]` instead of `[1, [p. 42]]`)

### Changed

- Refactor citation marker storage: store data in metadata value instead of label encoding, eliminating fragile `repr()`/decode round-trips and preserving content types natively

## [0.1.0] - 2026-01-29

Initial release on [Typst Universe](https://typst.app/universe/package/citrus).

[Unreleased]: https://github.com/pku-typst/citeproc-typst/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/pku-typst/citeproc-typst/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/pku-typst/citeproc-typst/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/pku-typst/citeproc-typst/releases/tag/v0.1.0

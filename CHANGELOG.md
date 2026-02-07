# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/pku-typst/citeproc-typst/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/pku-typst/citeproc-typst/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/pku-typst/citeproc-typst/releases/tag/v0.1.0

// citeproc-typst - Core Module
//
// Re-exports all core functionality.

#import "utils.typ": (
  capitalize-first-char, is-empty, join-with-delimiter, strip-periods-from-str,
  zero-pad,
)

#import "formatting.typ": apply-formatting, finalize

#import "context.typ": create-context

#import "state.typ": (
  _abbreviations, _bib-data, _cite-global-idx, _config, _csl-style, cite-marker,
  collect-citations, create-entry-ir, get-entry-year, get-first-author-family,
)

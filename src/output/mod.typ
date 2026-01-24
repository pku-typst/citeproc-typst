// citeproc-typst - Output Module
//
// Re-exports all output/rendering functionality.

#import "punctuation.typ": collapse-punctuation

#import "renderer.typ": (
  get-rendered-entries, process-entries, render-citation, render-entry,
  render-names-for-citation-display, render-names-for-grouping, select-layout,
)

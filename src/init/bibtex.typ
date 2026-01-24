// citeproc-typst - BibTeX Initialization Module
//
// Provides init-csl() for BibTeX bibliography loading.

#import "../core/mod.typ": _bib-data
#import "core.typ": _init-csl-core

/// Initialize the CSL citation system with BibTeX input
///
/// - bib: BibTeX file content (use `read("refs.bib")`)
/// - style: CSL file content (use `read("style.csl")`)
/// - locales: Optional dict of lang -> locale content for external locales
/// - show-url: Whether to show URLs in bibliography
/// - show-doi: Whether to show DOIs in bibliography
/// - show-accessed: Whether to show access dates in bibliography
/// - doc: Document content
#let init-csl(
  bib,
  style,
  locales: (:),
  show-url: true,
  show-doi: true,
  show-accessed: true,
  doc,
) = {
  import "@preview/citegeist:0.2.1": load-bibliography

  // Load bibliography data
  let bib-data = load-bibliography(bib)
  _bib-data.update(bib-data)

  _init-csl-core(
    style,
    locales: locales,
    show-url: show-url,
    show-doi: show-doi,
    show-accessed: show-accessed,
    doc,
    bib,
  )
}

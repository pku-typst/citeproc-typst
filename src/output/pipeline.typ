// citeproc-typst - IR Pipeline Module
//
// Functions for processing entries through the full IR (Intermediate Representation) pipeline.

#import "../core/state.typ": create-entry-ir
#import "../data/sorting.typ": sort-bibliography-entries
#import "../data/disambiguation.typ": apply-disambiguation
#import "helpers.typ": style-uses-citation-number
#import "names-render.typ": (
  get-first-bib-names-node, render-names-for-bibliography,
)
#import "entry.typ": render-citation-number, render-entry-ir

// =============================================================================
// IR Pipeline
// =============================================================================

/// Process entries through the full IR pipeline
///
/// Phase 1: Create IRs with order info
/// Phase 2: Sort entries
/// Phase 3: Apply disambiguation
///
/// - bib-data: Dictionary of key -> entry
/// - citations: Citation info from collect-citations()
/// - style: Parsed CSL style
/// Returns: Array of processed entry IRs, sorted and disambiguated
#let process-entries(bib-data, citations, style) = {
  // Phase 1: Create entry IRs
  let entries = citations
    .order
    .pairs()
    .map(((key, order)) => {
      let entry = bib-data.at(key, default: none)
      if entry == none { return none }
      create-entry-ir(key, entry, order, style)
    })
    .filter(x => x != none)

  // Determine if bibliography should be sorted by citation order
  // Check if style uses citation-number variable
  let uses-citation-number = style-uses-citation-number(style)

  // Phase 2: Sort entries
  // - If bibliography uses citation-number: sort by citation order
  // - Otherwise: use CSL <sort> if present
  let sorted-entries = sort-bibliography-entries(
    entries,
    style,
    by-order: uses-citation-number,
  )

  // Phase 3: Apply disambiguation
  let disambig-entries = apply-disambiguation(sorted-entries, style)

  disambig-entries
}

/// Get rendered bibliography entries
///
/// - bib-data: Dictionary of key -> entry
/// - citations: Citation info from collect-citations()
/// - style: Parsed CSL style
/// - abbreviations: Optional abbreviation lookup table
/// - precomputed: Optional precomputed data with sorted-keys and disambig-states
/// Returns: Array of (entry-ir, rendered, rendered-body, rendered-number, label) tuples
#let get-rendered-entries(
  bib-data,
  citations,
  style,
  abbreviations: (:),
  precomputed: none,
) = {
  // Use precomputed sorted order and disambig states if available
  let entries = if (
    precomputed != none
      and precomputed.at(
        "sorted-keys",
        default: none,
      )
        != none
  ) {
    let sorted-keys = precomputed.sorted-keys
    let disambig-states = precomputed.at("disambig-states", default: (:))

    // Reconstruct entries in cached sorted order with cached disambig
    sorted-keys
      .enumerate()
      .map(((idx, key)) => {
        let entry = bib-data.at(key, default: none)
        if entry == none { return none }
        let order = citations.order.at(key, default: idx)
        let ir = create-entry-ir(key, entry, order, style)
        // Apply cached disambiguation state
        let disambig = disambig-states.at(key, default: ir.disambig)
        (..ir, disambig: disambig)
      })
      .filter(x => x != none)
  } else {
    // Fall back to full processing
    process-entries(bib-data, citations, style)
  }

  // Get subsequent-author-substitute settings
  let bib-settings = style.at("bibliography", default: (:))
  let substitute = bib-settings.at(
    "subsequent-author-substitute",
    default: none,
  )
  let substitute-rule = bib-settings.at(
    "subsequent-author-substitute-rule",
    default: "complete-all",
  )

  // Get the first cs:names node in bibliography to identify which variables to substitute
  let first-names-node = get-first-bib-names-node(style)
  let substitute-vars = if first-names-node != none {
    first-names-node.at("attrs", default: (:)).at("variable", default: "author")
  } else { "author" }

  // Track previous entry's names for substitution
  let prev-names = none
  let result = ()

  for e in entries {
    // Get current entry's names string for comparison
    // Use bibliography layout, not citation layout
    let current-names = render-names-for-bibliography(
      e.entry,
      style,
      names-expanded: e.disambig.at("names-expanded", default: 0),
      givenname-level: e.disambig.at("givenname-level", default: 0),
    )

    // Determine if we should substitute
    let should-substitute = false
    if substitute != none and prev-names != none and current-names != "" {
      // CSL spec: comparison is limited to output of first cs:names element
      if (
        substitute-rule == "complete-all" or substitute-rule == "complete-each"
      ) {
        // Only substitute if all names match exactly
        should-substitute = current-names == prev-names
      } else if substitute-rule.starts-with("partial") {
        // Partial match: at least first name must match
        // For simplicity, we check if names start the same
        // A full implementation would compare name by name
        should-substitute = current-names == prev-names
      }
    }

    result.push((
      ir: e,
      rendered: render-entry-ir(
        e,
        style,
        include-number: true,
        abbreviations: abbreviations,
        author-substitute: if should-substitute { substitute } else { none },
        author-substitute-rule: substitute-rule,
        substitute-vars: substitute-vars,
      ),
      rendered-body: render-entry-ir(
        e,
        style,
        include-number: false,
        abbreviations: abbreviations,
        author-substitute: if should-substitute { substitute } else { none },
        author-substitute-rule: substitute-rule,
        substitute-vars: substitute-vars,
      ),
      rendered-number: render-citation-number(
        e.entry,
        style,
        cite-number: e.order,
      ),
      label: label("citeproc-ref-" + e.key),
    ))

    // Update previous names for next iteration
    prev-names = current-names
  }

  result
}

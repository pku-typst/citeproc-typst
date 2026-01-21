// citeproc-typst - Global state management
//
// Manages bibliography data, CSL style, and citation tracking.
// Uses metadata + query pattern for citation collection.

// =============================================================================
// Core State Variables
// =============================================================================

/// Bibliography data (key -> entry)
#let _bib-data = state("citeproc-bib-data", (:))

/// Parsed CSL style
#let _csl-style = state("citeproc-csl-style", none)

/// Display configuration
#let _config = state("citeproc-config", (
  show-url: true,
  show-doi: true,
  show-accessed: true,
))

// =============================================================================
// Citation Tracking (metadata + query pattern)
// =============================================================================

/// Place a citation marker in the document
///
/// This creates an invisible metadata element that can be queried later
/// to determine citation order and positions.
///
/// - key: Citation key
/// - locator: Optional locator (page, chapter, etc.)
/// Returns: Content (invisible metadata)
#let cite-marker(key, locator: none) = {
  [#metadata((key: key, locator: locator))<citeproc-cite>]
}

/// Collect all citations from the document
///
/// Must be called within a `context` block.
/// Returns a dictionary with:
/// - order: key -> first occurrence order (1-based)
/// - positions: key -> array of position info
/// - by-location: array of (key, index) in document order
/// - count: total unique citations
#let collect-citations() = {
  let cites = query(<citeproc-cite>)

  let result = (
    order: (:),
    positions: (:),
    by-location: (),
    count: 0,
  )

  let n = 0
  for c in cites {
    let info = c.value
    let key = info.key

    // Track first occurrence order
    if key not in result.order {
      n += 1
      result.order.insert(key, n)
      result.positions.insert(key, ())
    }

    // Track each occurrence's position
    let is-first = result.positions.at(key).len() == 0
    let prev-key = if result.by-location.len() > 0 {
      result.by-location.last().key
    } else { none }

    // Determine position type
    let position = if is-first {
      "first"
    } else if prev-key == key {
      // Same key as previous citation
      if info.locator != none { "ibid-with-locator" } else { "ibid" }
    } else {
      "subsequent"
    }

    result
      .positions
      .at(key)
      .push((
        index: result.by-location.len(),
        position: position,
        locator: info.locator,
      ))

    result.by-location.push((key: key, index: result.by-location.len()))
  }

  result.count = n
  result
}

// =============================================================================
// Entry IR (Intermediate Representation)
// =============================================================================

/// Create an enriched entry IR with computed fields
///
/// - key: Citation key
/// - entry: Raw entry from citegeist
/// - order: Citation order number (for numeric styles)
/// - style: Parsed CSL style
/// Returns: Enriched entry IR
#let create-entry-ir(key, entry, order, style) = {
  (
    // Original data
    key: key,
    entry: entry,
    order: order,
    // Will be populated by sorting/disambiguation
    sort-keys: (),
    disambig: (
      year-suffix: "",
      names-expanded: 0,
      add-givenname: false,
    ),
    // Fragments for disambiguation comparison (populated lazily)
    fragments: (:),
  )
}

/// Get the first author's family name (for grouping)
///
/// - entry: Entry from citegeist
/// Returns: First author family name or empty string
#let get-first-author-family(entry) = {
  let names = entry.at("parsed_names", default: (:)).at("author", default: ())
  if names.len() == 0 {
    names = entry.at("parsed_names", default: (:)).at("editor", default: ())
  }
  if names.len() > 0 {
    let first = names.first()
    let prefix = first.at("prefix", default: "")
    let family = first.at("family", default: "")
    if prefix != "" { prefix + " " + family } else { family }
  } else {
    ""
  }
}

/// Get the year from an entry
///
/// - entry: Entry from citegeist
/// Returns: Year string or empty string
#let get-entry-year(entry) = {
  let fields = entry.at("fields", default: (:))
  str(fields.at("year", default: fields.at("date", default: "")))
}

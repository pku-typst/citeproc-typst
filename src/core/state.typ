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

/// Abbreviations data (jurisdiction -> variable -> value -> abbreviated)
/// Structure: { "default": { "title": { "Full Title": "Abbr" }, ... }, ... }
#let _abbreviations = state("citeproc-abbreviations", (:))

// =============================================================================
// Citation Tracking (metadata + query pattern)
// =============================================================================

/// Place a citation marker in the document
///
/// This creates an invisible metadata element that can be queried later
/// to determine citation order and positions.
///
/// Uses a complex label encoding key+locator for precise querying.
/// This avoids counter-based occurrence tracking which can cause
/// layout convergence issues when page settings change mid-document.
///
/// Design:
/// - Fixed metadata value "citeproc-cite" enables efficient metadata.where() query
/// - Complex label encodes key+locator for selector.before(here()) queries
/// - Label string (via repr) is used as hashmap key, avoiding parsing
///
/// - key: Citation key
/// - locator: Optional locator (page, chapter, etc.)
/// Returns: Content (invisible metadata)
#let cite-marker(key, locator: none) = {
  // Complex label: encode key and locator with unlikely separator
  let complex-key = "citeproc|||" + key + "|||" + repr(locator)
  let lbl = label(complex-key)
  // Fixed value for efficient metadata.where() query
  [#metadata("citeproc-cite")#lbl]
}

/// Collect all citations from the document
///
/// Must be called within a `context` block.
/// Returns a dictionary with:
/// - order: key -> first occurrence order (1-based)
/// - positions: positions-key -> array of position info (key is "key|||repr(locator)")
/// - by-location: array of (key, occurrence) in document order
/// - count: total unique citations
/// - first-note-numbers: key -> note number of first occurrence (for note styles)
///
/// Note: positions uses "key|||repr(locator)" as key (e.g., "smith2020|||none")
/// to enable O(1) lookup in show rules.
#let collect-citations() = {
  // Efficient query using fixed metadata value
  let cites = query(metadata.where(value: "citeproc-cite"))

  let result = (
    order: (:),
    positions: (:),
    by-location: (),
    count: 0,
    first-note-numbers: (:),
  )

  let n = 0
  let note-number = 0 // Track note numbers (each citation in note style = one footnote)
  let prev-key = none

  for c in cites {
    // Parse label to extract key and locator
    // Label format: "citeproc|||{key}|||{repr(locator)}"
    let label-str = str(c.label)
    let parts = label-str.split("|||")
    let key = parts.at(1)
    let locator-repr = parts.slice(2).join("|||")

    // Hashmap key: just "key|||locator-repr" (no prefix needed internally)
    let positions-key = key + "|||" + locator-repr

    // Parse locator back from repr (handles "none" and quoted strings)
    let locator = if locator-repr == "none" {
      none
    } else if locator-repr.starts-with("\"") and locator-repr.ends-with("\"") {
      locator-repr.slice(1, -1)
    } else {
      locator-repr
    }

    note-number += 1

    // Track first occurrence order (by key, not positions-key)
    if key not in result.order {
      n += 1
      result.order.insert(key, n)
      result.first-note-numbers.insert(key, note-number)
    }

    // Initialize positions array if needed
    if positions-key not in result.positions {
      result.positions.insert(positions-key, ())
    }

    // Track each occurrence's position
    let is-first = result.positions.at(positions-key).len() == 0
    let is-first-of-key = result.order.at(key) == n and is-first

    // Determine position type
    let position = if is-first-of-key {
      "first"
    } else if prev-key == key {
      // Same key as previous citation
      if locator != none { "ibid-with-locator" } else { "ibid" }
    } else {
      "subsequent"
    }

    // Use per-positions-key occurrence (1-based)
    let occurrence = result.positions.at(positions-key).len() + 1

    result
      .positions
      .at(positions-key)
      .push((
        occurrence: occurrence,
        position: position,
        key: key,
        locator: locator,
        note-number: note-number,
      ))

    result.by-location.push((
      key: key,
      positions-key: positions-key,
      occurrence: occurrence,
    ))
    prev-key = key
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

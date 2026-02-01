// citrus - Sorting Module
//
// Extracts sort keys from CSL <sort> element and sorts entries.

#import "variables.typ": NAME-VARS, get-variable
#import "../interpreter/mod.typ": create-context
#import "../interpreter/stack.typ": interpret-children-stack
#import "../output/helpers.typ": content-to-string

// =============================================================================
// Sort Key Extraction
// =============================================================================

/// Extract a single sort key value from an entry
///
/// - key-spec: Sort key specification from CSL (variable, macro, sort order)
/// - entry: Entry from citegeist
/// - style: Parsed CSL style
/// Returns: (order, value) tuple
#let extract-sort-key(key-spec, entry, style) = {
  let ctx = create-context(style, entry)
  let order = key-spec.at("sort", default: "ascending")

  // CSL spec: names-min/use-first/use-last override et-al settings for sort keys
  // Pass these to the context for names rendering within macros
  let names-min = key-spec.at("names-min", default: none)
  let names-use-first = key-spec.at("names-use-first", default: none)
  let names-use-last = key-spec.at("names-use-last", default: none)

  // Add sort key name settings to context (they override et-al settings)
  let ctx = (
    ..ctx,
    sort-names-min: names-min,
    sort-names-use-first: names-use-first,
    sort-names-use-last: names-use-last,
  )

  let value = if key-spec.at("macro", default: none) != none {
    // Render macro and use result as sort key
    let macro-name = key-spec.macro
    let macro-def = style.macros.at(macro-name, default: none)
    if macro-def != none {
      let rendered = interpret-children-stack(macro-def.children, ctx)
      // Convert to string for sorting
      content-to-string(rendered)
    } else { "" }
  } else if key-spec.at("variable", default: "") != "" {
    let var-name = key-spec.variable
    // Special handling for name variables: construct sort key from parsed names
    if var-name in NAME-VARS {
      let parsed-names = ctx.at("parsed-names", default: (:))
      let names-list = parsed-names.at(var-name, default: ())
      if names-list.len() > 0 {
        // CSL spec: sort key is constructed from name parts
        // For literal names: use literal value
        // For structured names: "family given" for each name, joined by space
        names-list
          .map(name => {
            if name.at("literal", default: "") != "" {
              name.literal
            } else {
              let family = name.at("family", default: "")
              let given = name.at("given", default: "")
              let prefix = name.at("prefix", default: "") // non-dropping particle
              // CSL sort order: family prefix given
              (family, prefix, given).filter(p => p != "").join(" ")
            }
          })
          .join(" ")
      } else { "" }
    } else if (
      var-name in ("issued", "accessed", "original-date", "event-date")
    ) {
      // Date variables need special handling for proper numeric sorting
      // Construct a sortable date string with year offset for proper ordering
      let fields = ctx.fields

      // Helper to build sortable date string
      let build-sortable-date(year-str, month-str, day-str) = {
        if year-str == "" { return "" }
        let month = if month-str == "" { "01" } else { month-str }
        let day = if day-str == "" { "01" } else { day-str }

        // Pad month and day to 2 digits
        let month-padded = if month.len() == 1 { "0" + month } else { month }
        let day-padded = if day.len() == 1 { "0" + day } else { day }

        // Convert year to sortable format (handle negative years)
        // Offset by large number to ensure all values are positive
        // Use 100000000 so that even very old dates (e.g., -5000 BC) are positive
        // Pad to fixed length (9 digits) for proper string comparison
        let year-int = int(year-str)
        let year-offset = 100000000 + year-int
        // Pad to 9 digits: e.g., 99999900 for -100, 100002024 for 2024
        let year-str-padded = str(year-offset)
        // Ensure 9 digit length by padding with leading zeros if needed
        let year-sortable = if year-str-padded.len() < 9 {
          "0" * (9 - year-str-padded.len()) + year-str-padded
        } else {
          year-str-padded
        }

        year-sortable + "-" + month-padded + "-" + day-padded
      }

      if var-name == "issued" {
        let year-str = fields.at("year", default: "")
        if year-str != "" {
          build-sortable-date(
            year-str,
            fields.at("month", default: ""),
            fields.at("day", default: ""),
          )
        } else {
          // Try 'date' field as fallback
          let date-str = fields.at("date", default: "")
          if date-str != "" {
            let parts = date-str.split("-")
            let year = if parts.len() >= 1 { parts.at(0) } else { "" }
            let month = if parts.len() >= 2 { parts.at(1) } else { "" }
            let day = if parts.len() >= 3 { parts.at(2) } else { "" }
            build-sortable-date(year, month, day)
          } else { "" }
        }
      } else if var-name == "accessed" {
        build-sortable-date(
          fields.at("accessed-year", default: ""),
          fields.at("accessed-month", default: ""),
          fields.at("accessed-day", default: ""),
        )
      } else if var-name == "original-date" {
        let origdate = fields.at("origdate", default: "")
        if origdate != "" {
          let parts = origdate.split("-")
          let year = if parts.len() >= 1 { parts.at(0) } else { "" }
          let month = if parts.len() >= 2 { parts.at(1) } else { "" }
          let day = if parts.len() >= 3 { parts.at(2) } else { "" }
          build-sortable-date(year, month, day)
        } else { "" }
      } else {
        // event-date
        let eventdate = fields.at("eventdate", default: "")
        if eventdate != "" {
          let parts = eventdate.split("-")
          let year = if parts.len() >= 1 { parts.at(0) } else { "" }
          let month = if parts.len() >= 2 { parts.at(1) } else { "" }
          let day = if parts.len() >= 3 { parts.at(2) } else { "" }
          build-sortable-date(year, month, day)
        } else { "" }
      }
    } else {
      // Get regular variable value directly
      get-variable(ctx, var-name)
    }
  } else {
    ""
  }

  // Normalize for case-insensitive sorting
  let normalized = if type(value) == str { lower(value) } else { "" }

  (order: order, value: normalized)
}

/// Extract all sort keys for an entry
///
/// - entry: Entry from citegeist
/// - sort-spec: Array of sort key specifications from CSL
/// - style: Parsed CSL style
/// Returns: Array of (order, value) tuples
#let extract-sort-keys(entry, sort-spec, style) = {
  if sort-spec == none or sort-spec.len() == 0 {
    return ()
  }

  sort-spec.map(key-spec => extract-sort-key(key-spec, entry, style))
}

// =============================================================================
// Entry Sorting
// =============================================================================

/// Compare two entries by their sort keys
///
/// - a: First entry IR (with sort-keys)
/// - b: Second entry IR (with sort-keys)
/// Returns: -1, 0, or 1
#let compare-entries(a, b) = {
  let keys-a = a.sort-keys
  let keys-b = b.sort-keys

  let len = calc.min(keys-a.len(), keys-b.len())

  for i in range(len) {
    let ka = keys-a.at(i)
    let kb = keys-b.at(i)

    let va = ka.value
    let vb = kb.value

    if va != vb {
      let cmp = if va < vb { -1 } else { 1 }
      // Reverse for descending order
      if ka.order == "descending" { return -cmp }
      return cmp
    }
  }

  0
}

/// Invert a string for descending sort (complement each character)
///
/// For proper descending sort with string comparison, we need to invert
/// the string so that "larger" values become "smaller" in the inverted form.
#let invert-for-descending(s) = {
  if s == "" { return "" }
  // For each character, compute its "complement" to reverse sort order
  // We use a simple approach: prefix with "~" and negate digits
  // Map: 0->9, 1->8, 2->7, 3->6, 4->5, 5->4, 6->3, 7->2, 8->1, 9->0
  // For letters: a->z, b->y, etc.
  s.codepoints().map(c => {
    let code = c.to-unicode()
    if code >= 0x30 and code <= 0x39 {
      // Digit: 0-9 -> 9-0
      str.from-unicode(0x39 - (code - 0x30))
    } else if code >= 0x61 and code <= 0x7a {
      // Lowercase: a-z -> z-a
      str.from-unicode(0x7a - (code - 0x61))
    } else if code >= 0x41 and code <= 0x5a {
      // Uppercase: A-Z -> Z-A
      str.from-unicode(0x5a - (code - 0x41))
    } else {
      // Keep other characters (like -)
      c
    }
  }).join()
}

/// Sort entries by extracted sort keys
///
/// - entries: Array of entry IRs with sort-keys populated
/// Returns: Sorted array of entry IRs
#let sort-entries(entries) = {
  if entries.len() <= 1 { return entries }

  // Typst's sorted() with a key function
  // For multi-key sorting, we create a compound key
  entries.sorted(key: e => {
    e
      .sort-keys
      .map(k => {
        // For descending order, invert the value so string comparison works
        if k.order == "descending" {
          "1" + invert-for-descending(k.value)
        } else {
          "0" + k.value
        }
      })
      .join("\x00") // Use null byte as separator (won't appear in text)
  })
}

/// Sort entries for bibliography output
///
/// For numeric styles: sort by citation order
/// For author-date styles: sort by CSL <sort> element
///
/// - entries: Array of entry IRs
/// - style: Parsed CSL style
/// - by-order: If true, sort by citation order (for numeric styles)
/// Returns: Sorted array of entry IRs
#let sort-bibliography-entries(entries, style, by-order: false) = {
  if by-order {
    // Sort by citation order (numeric styles)
    entries.sorted(key: e => e.order)
  } else {
    // Sort by CSL sort keys (with null-safety for citation-only styles)
    let bib = style.at("bibliography", default: none)
    let sort-spec = if bib != none { bib.at("sort", default: ()) } else { () }

    if sort-spec.len() == 0 {
      // No sort specified, keep original order
      return entries
    }

    // Extract sort keys for each entry
    let with-keys = entries.map(e => {
      let keys = extract-sort-keys(e.entry, sort-spec, style)
      (..e, sort-keys: keys)
    })

    sort-entries(with-keys)
  }
}

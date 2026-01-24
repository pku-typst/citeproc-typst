// citeproc-typst - Disambiguation Module
//
// Computes year suffixes and other disambiguation markers for author-date styles.
// Implements CSL disambiguation options:
// - disambiguate-add-year-suffix: Add a, b, c to years
// - disambiguate-add-names: Add more author names
// - disambiguate-add-givenname: Expand initials to full given names
// - givenname-disambiguation-rule: Controls given name expansion scope

#import "state.typ": get-entry-year, get-first-author-family

// =============================================================================
// Year Suffix Computation
// =============================================================================

/// Compute year suffixes for entries that need disambiguation
///
/// Groups entries by (first-author, year) and assigns a, b, c, ... suffixes
/// to entries within the same group.
///
/// - entries: Array of entry IRs
/// - style: Parsed CSL style
/// Returns: Dictionary of key -> suffix (e.g., "smith2020" -> "a")
#let compute-year-suffixes(entries, style) = {
  // Check if style uses year-suffix disambiguation
  let citation = style.at("citation", default: none)
  if citation == none { return (:) }

  let use-year-suffix = citation.at(
    "disambiguate-add-year-suffix",
    default: false,
  )
  if not use-year-suffix { return (:) }

  // Group entries by (first-author-family, year)
  // Record original index to preserve bibliography order per CSL spec:
  // "The assignment of year-suffixes follows the order of the bibliographies entries"
  let groups = (:)
  for (idx, e) in entries.enumerate() {
    let entry = e.entry
    let author = get-first-author-family(entry)
    let year = get-entry-year(entry)
    let group-key = lower(author) + "|" + str(year)

    if group-key not in groups {
      groups.insert(group-key, ())
    }
    groups
      .at(group-key)
      .push((
        key: e.key,
        index: idx, // Position in bibliography (already sorted)
      ))
  }

  // Assign suffixes to groups with multiple entries
  let suffixes = (:)
  let suffix-chars = "abcdefghijklmnopqrstuvwxyz"

  for (group-key, items) in groups.pairs() {
    if items.len() > 1 {
      // Sort by bibliography order (index), not by title
      let sorted-items = items.sorted(key: it => it.index)

      for (i, item) in sorted-items.enumerate() {
        if i < suffix-chars.len() {
          suffixes.insert(item.key, suffix-chars.at(i))
        }
      }
    }
  }

  suffixes
}

// =============================================================================
// Name Disambiguation
// =============================================================================

/// Get all authors from an entry as a list of parsed names
///
/// - entry: Entry from citegeist
/// Returns: Array of name dicts with (family, given, literal)
#let get-all-authors(entry) = {
  let fields = entry.at("fields", default: (:))
  let author-field = fields.at("author", default: none)
  if author-field == none { return () }

  let parsed = entry.at("parsed-names", default: (:))
  parsed.at("author", default: ())
}

/// Get initials from a given name
///
/// - given: Full given name string (e.g., "John Michael")
/// Returns: Initials string (e.g., "J. M.")
#let get-initials(given) = {
  if given == none or given == "" { return "" }
  let parts = given.split(regex("\\s+"))
  parts
    .filter(p => p.len() > 0)
    .map(p => {
      // Handle Unicode - use clusters for first character
      let clusters = p.clusters()
      if clusters.len() > 0 { clusters.at(0) + "." } else { "" }
    })
    .join(" ")
}

/// Build author short representation with given disambiguation level
///
/// - names: Array of parsed name dicts
/// - et-al-use-first: Number of names before et al.
/// - expand-names: Number of additional names to show beyond et-al-use-first
/// - givenname-level: 0 = none, 1 = initials, 2 = full given
/// Returns: String representation for comparison
#let build-author-key(
  names,
  et-al-use-first,
  expand-names: 0,
  givenname-level: 0,
) = {
  if names.len() == 0 { return "" }

  let show-count = calc.min(names.len(), et-al-use-first + expand-names)
  let parts = ()

  for i in range(show-count) {
    let name = names.at(i)
    let family = name.at("family", default: name.at("literal", default: ""))

    let given-part = if givenname-level == 0 {
      ""
    } else if givenname-level == 1 {
      get-initials(name.at("given", default: ""))
    } else {
      name.at("given", default: "")
    }

    if given-part != "" {
      parts.push(family + ", " + given-part)
    } else {
      parts.push(family)
    }
  }

  lower(parts.join("; "))
}

/// Compute name disambiguation levels for entries
///
/// Returns a dictionary of entry key -> (names-expanded, givenname-level)
///
/// - entries: Array of entry IRs
/// - style: Parsed CSL style
/// Returns: Dictionary of key -> (names-expanded: int, givenname-level: int)
#let compute-name-disambiguation(entries, style) = {
  let citation = style.at("citation", default: none)
  if citation == none { return (:) }

  let add-names = citation.at("disambiguate-add-names", default: false)
  let add-givenname = citation.at("disambiguate-add-givenname", default: false)
  let givenname-rule = citation.at(
    "givenname-disambiguation-rule",
    default: "by-cite",
  )

  if not add-names and not add-givenname { return (:) }

  let et-al-min = citation.at("et-al-min", default: 4)
  let et-al-use-first = citation.at("et-al-use-first", default: 1)

  // Convert to integers if needed
  if type(et-al-min) == str { et-al-min = int(et-al-min) }
  if type(et-al-use-first) == str { et-al-use-first = int(et-al-use-first) }

  // Build initial representations for all entries
  let disambig-state = (:)
  for e in entries {
    let authors = get-all-authors(e.entry)
    disambig-state.insert(e.key, (
      authors: authors,
      names-expanded: 0,
      givenname-level: 0,
      year: get-entry-year(e.entry),
    ))
  }

  // Iteratively disambiguate
  // Strategy: Start with minimal representation, expand as needed
  let max-iterations = 10
  let iteration = 0

  while iteration < max-iterations {
    iteration += 1
    let made-change = false

    // Build current keys
    let keys = (:)
    for (entry-key, state) in disambig-state.pairs() {
      let author-key = build-author-key(
        state.authors,
        et-al-use-first,
        expand-names: state.names-expanded,
        givenname-level: state.givenname-level,
      )
      let full-key = author-key + "|" + str(state.year)

      if full-key not in keys {
        keys.insert(full-key, ())
      }
      keys.at(full-key).push(entry-key)
    }

    // Find collisions and try to resolve
    for (full-key, colliding-keys) in keys.pairs() {
      if colliding-keys.len() > 1 {
        // Try disambiguation strategies in order:
        // 1. Add givenname (initials first, then full)
        // 2. Add more names

        for entry-key in colliding-keys {
          let state = disambig-state.at(entry-key)
          let resolved = false

          // Try expanding givenname first
          if add-givenname and state.givenname-level < 2 {
            let new-level = state.givenname-level + 1
            let new-key = build-author-key(
              state.authors,
              et-al-use-first,
              expand-names: state.names-expanded,
              givenname-level: new-level,
            )

            // Check if this would resolve collision
            let would-resolve = true
            for other-key in colliding-keys {
              if other-key != entry-key {
                let other = disambig-state.at(other-key)
                let other-new-key = build-author-key(
                  other.authors,
                  et-al-use-first,
                  expand-names: other.names-expanded,
                  givenname-level: other.givenname-level,
                )
                if new-key == other-new-key {
                  would-resolve = false
                }
              }
            }

            if would-resolve or state.givenname-level < 2 {
              disambig-state.insert(entry-key, (
                ..state,
                givenname-level: new-level,
              ))
              made-change = true
              resolved = true
            }
          }

          // Try adding more names
          if not resolved and add-names {
            let max-names = state.authors.len()
            if state.names-expanded + et-al-use-first < max-names {
              disambig-state.insert(entry-key, (
                ..state,
                names-expanded: state.names-expanded + 1,
              ))
              made-change = true
            }
          }
        }
      }
    }

    if not made-change { break }
  }

  // Convert to result format
  let result = (:)
  for (entry-key, state) in disambig-state.pairs() {
    result.insert(entry-key, (
      names-expanded: state.names-expanded,
      givenname-level: state.givenname-level,
    ))
  }

  result
}

/// Apply disambiguation to entry IRs
///
/// - entries: Array of entry IRs
/// - style: Parsed CSL style
/// Returns: Array of entry IRs with disambig field populated
#let apply-disambiguation(entries, style) = {
  let suffixes = compute-year-suffixes(entries, style)
  let name-disambig = compute-name-disambiguation(entries, style)

  entries.map(e => {
    let suffix = suffixes.at(e.key, default: "")
    let name-info = name-disambig.at(e.key, default: (
      names-expanded: 0,
      givenname-level: 0,
    ))

    (
      ..e,
      disambig: (
        year-suffix: suffix,
        names-expanded: name-info.names-expanded,
        givenname-level: name-info.givenname-level,
      ),
    )
  })
}

/// Check if two entries have the same short author representation
///
/// - entry-a: First entry
/// - entry-b: Second entry
/// Returns: bool
#let same-author-short(entry-a, entry-b) = {
  let author-a = get-first-author-family(entry-a)
  let author-b = get-first-author-family(entry-b)
  lower(author-a) == lower(author-b)
}

/// Check if two entries have the same year
///
/// - entry-a: First entry
/// - entry-b: Second entry
/// Returns: bool
#let same-year(entry-a, entry-b) = {
  let year-a = get-entry-year(entry-a)
  let year-b = get-entry-year(entry-b)
  year-a == year-b
}

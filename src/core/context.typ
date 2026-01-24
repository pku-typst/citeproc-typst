// citeproc-typst - Interpretation Context
//
// Creates the context object used during CSL interpretation.

// =============================================================================
// Context Creation
// =============================================================================

/// Create interpretation context
/// - cite-number: Optional citation number to inject
/// - abbreviations: Optional abbreviation lookup table
/// - disambiguate: Optional flag for CSL disambiguate condition (Method 3)
#let create-context(
  style,
  entry,
  cite-number: none,
  abbreviations: (:),
  disambiguate: false,
) = {
  let fields = entry.at("fields", default: (:))
  let is-csl-json = fields.at("_source", default: "") == "csl-json"

  // Inject citation number if provided
  if cite-number != none {
    fields.insert("citation-number", str(cite-number))
  }

  // Map CSL name variables to BibTeX name fields
  let raw-names = entry.at("parsed_names", default: (:))
  let mapped-names = raw-names

  // For CSL-JSON, names are already in CSL format (author, editor, container-author, etc.)
  // For BibTeX, we need to map some fields
  if not is-csl-json {
    // Add CSL variable aliases for BibTeX fields
    // container-author -> bookauthor (for chapters in books)
    if "bookauthor" in raw-names and "container-author" not in raw-names {
      mapped-names.insert("container-author", raw-names.at("bookauthor"))
    }

    // CSL-M original-* name variables (for bilingual entries)
    // Maps to BibTeX -en suffix fields if parsed by citegeist
    if "author-en" in raw-names and "original-author" not in raw-names {
      mapped-names.insert("original-author", raw-names.at("author-en"))
    }
    if "editor-en" in raw-names and "original-editor" not in raw-names {
      mapped-names.insert("original-editor", raw-names.at("editor-en"))
    }
  }

  // Determine entry type
  // For CSL-JSON, use csl-type field directly if available
  let entry-type = if is-csl-json and "csl-type" in fields {
    fields.at("csl-type")
  } else {
    entry.at("entry_type", default: "misc")
  }

  (
    style: style,
    entry: entry,
    macros: style.macros,
    locale: style.locale,
    fields: fields,
    parsed-names: mapped-names,
    entry-type: entry-type,
    is-csl-json: is-csl-json,
    abbreviations: abbreviations,
    disambiguate: disambiguate,
  )
}

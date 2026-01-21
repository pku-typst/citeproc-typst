// citeproc-typst - Variable Access
//
// Functions for accessing entry variables/fields
// Includes CSL-M legal variable extensions

/// Get variable value from context
/// Handles CSL variable names and maps to BibTeX fields
#let get-variable(ctx, name) = {
  let fields = ctx.fields
  let entry-type = ctx.entry-type

  // Direct field mappings (including CSL-M legal variables)
  let field-map = (
    // Standard CSL variables
    "title": "title",
    "publisher-place": "address",
    "page": "pages",
    "volume": "volume",
    "issue": "number",
    "URL": "url",
    "DOI": "doi",
    "ISBN": "isbn",
    "ISSN": "issn",
    "edition": "edition",
    "note": "note",
    "abstract": "abstract",
    "archive": "archive",
    "archive_location": "archiveprefix",
    "number": "number",
    "genre": "type",
    "event-title": "eventtitle",
    "collection-title": "series",
    "number-of-volumes": "volumes",
    // CSL-M legal variables
    "authority": "authority",
    "jurisdiction": "jurisdiction",
    "committee": "committee",
    "document-name": "document-name",
    "hereinafter": "hereinafter",
    "supplement": "supplement",
    "division": "division",
    "gazette-flag": "gazette-flag",
    "volume-title": "volume-title",
    "publication-number": "publication-number",
    "locator-extra": "locator-extra",
    "references": "references",
    "chapter-number": "chapter",
    "section": "section",
    "article": "article",
  )

  // Handle special variables
  if name == "citation-number" {
    return fields.at("citation-number", default: "")
  }

  if name == "year-suffix" {
    // Year suffix for disambiguation (e.g., "a", "b") - stored in context
    return ctx.at("year-suffix", default: "")
  }

  if name == "publisher" {
    // For thesis, use school; otherwise use publisher
    if (
      entry-type == "phdthesis"
        or entry-type == "mastersthesis"
        or entry-type == "thesis"
    ) {
      let school = fields.at("school", default: "")
      if school != "" { return school }
    }
    return fields.at("publisher", default: "")
  }

  if name == "container-title" {
    // Container depends on entry type
    let journal = fields.at("journal", default: "")
    if journal != "" { return journal }
    let booktitle = fields.at("booktitle", default: "")
    if booktitle != "" { return booktitle }
    return ""
  }

  if name == "collection-title" {
    return fields.at("series", default: "")
  }

  if name == "event-title" {
    return fields.at("eventtitle", default: fields.at("booktitle", default: ""))
  }

  // Date variables - check if date exists
  if name == "issued" {
    // Return year as a proxy for "issued has value"
    return fields.at("year", default: fields.at("date", default: ""))
  }

  if name == "accessed" {
    // URL access date - typically urldate in BibTeX
    return fields.at("urldate", default: "")
  }

  if name == "original-date" {
    return fields.at("origdate", default: "")
  }

  // CSL-M special variables

  // Country (virtual variable from jurisdiction)
  if name == "country" {
    let jurisdiction = fields.at("jurisdiction", default: "")
    if jurisdiction != "" {
      let parts = jurisdiction.split(":")
      return parts.first()
    }
    return ""
  }

  // Available date (CSL-M: date available for signing, e.g., treaties)
  if name == "available-date" {
    return fields.at("available-date", default: fields.at(
      "availabledate",
      default: "",
    ))
  }

  // Publication date (CSL-M: date published in gazette/reporter)
  if name == "publication-date" {
    return fields.at("publication-date", default: fields.at(
      "pubdate",
      default: "",
    ))
  }

  // Language-name (CSL-M: ISO language code from language field vector)
  if name == "language-name" {
    let lang = fields.at("language", default: "")
    if lang.contains(">") {
      let parts = lang.split(">")
      return parts.at(1, default: "").trim()
    } else if lang.contains("<") {
      let parts = lang.split("<")
      return parts.at(0, default: "").trim()
    }
    return ""
  }

  // Language-name-original (CSL-M: source language from vector)
  if name == "language-name-original" {
    let lang = fields.at("language", default: "")
    if lang.contains(">") {
      let parts = lang.split(">")
      return parts.at(0, default: "").trim()
    } else if lang.contains("<") {
      let parts = lang.split("<")
      return parts.at(1, default: "").trim()
    }
    return ""
  }

  // Standard mapping
  let field-name = field-map.at(name, default: name)
  fields.at(field-name, default: "")
}

/// Check if variable exists and has value
#let has-variable(ctx, name) = {
  let val = get-variable(ctx, name)
  val != none and val != ""
}

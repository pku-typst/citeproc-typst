// citeproc-typst - Entry and Citation Renderer
//
// High-level rendering functions with IR pipeline integration.

#import "interpreter.typ": create-context, interpret-node
#import "locales.typ": detect-language, locale-matches
#import "names.typ": format-names
#import "state.typ": create-entry-ir, get-entry-year, get-first-author-family
#import "sorting.typ": sort-bibliography-entries
#import "disambiguation.typ": apply-disambiguation

/// Check if style uses citation-number variable
/// Uses simple string search on macro definitions instead of recursive AST traversal
/// This avoids stack overflow on deeply nested CSL structures
#let style-uses-citation-number(style) = {
  // Check if any macro definition contains citation-number reference
  let macros = style.at("macros", default: (:))
  for (name, macro-def) in macros {
    // Check children of macro for text variable="citation-number"
    let children = macro-def.at("children", default: ())
    for child in children {
      if type(child) == dictionary {
        let tag = child.at("tag", default: "")
        let attrs = child.at("attrs", default: (:))
        if (
          tag == "text"
            and attrs.at("variable", default: "") == "citation-number"
        ) {
          return true
        }
      }
    }
  }

  // Check bibliography layouts directly (first level only)
  let bib = style.at("bibliography", default: none)
  if bib != none {
    let layouts = bib.at("layouts", default: ())
    for layout in layouts {
      let children = layout.at("children", default: ())
      for child in children {
        if type(child) == dictionary {
          let tag = child.at("tag", default: "")
          let attrs = child.at("attrs", default: (:))
          // Direct citation-number reference
          if (
            tag == "text"
              and attrs.at("variable", default: "") == "citation-number"
          ) {
            return true
          }
          // Macro named "citation-number" (common pattern)
          if (
            tag == "text"
              and attrs.at("macro", default: "") == "citation-number"
          ) {
            return true
          }
        }
      }
    }
  }

  false
}

// =============================================================================
// Layout Selection (CSL-M enhanced)
// =============================================================================

/// Select appropriate layout based on entry language
///
/// Supports CSL-M multilingual layout selection where each layout
/// can specify a locale attribute with space-separated language codes.
///
/// Examples:
///   - <layout locale="en es de"> matches entries in English, Spanish, German
///   - <layout locale="zh"> matches Chinese entries
///   - <layout> (no locale) is the default fallback
///
/// - layouts: Array of layout nodes from CSL
/// - entry-lang: The entry's detected language (e.g., "en", "zh-CN")
/// Returns: Matching layout node or none
#let select-layout(layouts, entry-lang) = {
  if layouts.len() == 0 { return none }

  // Try to find locale-specific layout using CSL-M matching
  let matching = layouts.find(l => {
    let locale = l.at("locale", default: none)
    if locale == none { return false }
    locale-matches(entry-lang, locale)
  })

  if matching != none { return matching }

  // Fallback to layout without locale (default/last)
  let default = layouts.find(l => l.at("locale", default: none) == none)
  if default != none { return default }

  // Last resort: last layout (CSL-M spec: last layout is default)
  layouts.last()
}

// =============================================================================
// Entry Rendering
// =============================================================================

/// Check if a node uses citation-number variable (for filtering)
/// Handles both direct <text variable="citation-number"> and <text macro="citation-number">
#let _node-uses-citation-number(node) = {
  if type(node) != dictionary { return false }
  if node.at("tag", default: "") == "text" {
    let attrs = node.at("attrs", default: (:))
    let var = attrs.at("variable", default: "")
    if var == "citation-number" { return true }
    // Also check for macro named "citation-number" (common pattern)
    let macro-name = attrs.at("macro", default: "")
    if macro-name == "citation-number" { return true }
  }
  false
}

/// Render only the citation number for an entry
///
/// - entry: Bibliography entry from citegeist
/// - style: Parsed CSL style
/// - cite-number: Citation number for numeric styles
/// Returns: Typst content (just the formatted number, e.g., "〔1〕")
#let render-citation-number(entry, style, cite-number: none) = {
  let ctx = create-context(style, entry, cite-number: cite-number)
  let entry-lang = detect-language(entry.at("fields", default: (:)))

  let bib = style.at("bibliography", default: none)
  if bib == none { return [] }

  let layout = select-layout(bib.at("layouts", default: ()), entry-lang)
  if layout == none { return [] }

  // Find and render only the citation-number node
  let number-nodes = layout.children.filter(node => _node-uses-citation-number(
    node,
  ))
  if number-nodes.len() > 0 {
    number-nodes.map(node => interpret-node(node, ctx)).join()
  } else {
    // Fallback: simple bracketed number
    [[#cite-number]]
  }
}

/// Render a bibliography entry
///
/// - entry: Bibliography entry from citegeist
/// - style: Parsed CSL style
/// - cite-number: Citation number for numeric styles
/// - year-suffix: Year suffix for disambiguation (e.g., "a", "b")
/// - include-number: Whether to include citation number in output
/// Returns: Typst content
#let render-entry(
  entry,
  style,
  cite-number: none,
  year-suffix: "",
  include-number: true,
  abbreviations: (:),
) = {
  let ctx = create-context(
    style,
    entry,
    cite-number: cite-number,
    abbreviations: abbreviations,
  )

  // Inject year suffix into context for rendering
  let ctx = (..ctx, year-suffix: year-suffix)

  let entry-lang = detect-language(entry.at("fields", default: (:)))

  // Find matching layout (with null-safety for citation-only styles)
  let bib = style.at("bibliography", default: none)
  if bib == none {
    return text(fill: red, "[No bibliography element in CSL]")
  }

  let layout = select-layout(bib.at("layouts", default: ()), entry-lang)

  if layout == none {
    return text(fill: red, "[No bibliography layout defined]")
  }

  // Filter out citation-number nodes if requested
  let children = if include-number {
    layout.children
  } else {
    layout.children.filter(node => not _node-uses-citation-number(node))
  }

  // Interpret layout children
  let result = children
    .map(node => interpret-node(node, ctx))
    .filter(x => x != [] and x != "")
    .join()

  // Apply layout suffix (usually ".")
  let layout-suffix = layout.at("suffix", default: ".")
  [#result#layout-suffix]
}

/// Render a bibliography entry from an entry IR
///
/// - entry-ir: Entry IR with disambig info
/// - style: Parsed CSL style
/// - include-number: Whether to include citation number in output
/// - abbreviations: Optional abbreviation lookup table
/// Returns: Typst content
#let render-entry-ir(
  entry-ir,
  style,
  include-number: true,
  abbreviations: (:),
) = {
  render-entry(
    entry-ir.entry,
    style,
    cite-number: entry-ir.order,
    year-suffix: entry-ir.disambig.at("year-suffix", default: ""),
    include-number: include-number,
    abbreviations: abbreviations,
  )
}

// =============================================================================
// Citation Rendering
// =============================================================================

/// Render an in-text citation
///
/// - entry: Bibliography entry
/// - style: Parsed CSL style
/// - form: Citation form (none, "normal", "prose", "author", "year")
/// - supplement: Page number or other supplement
/// - cite-number: Citation number (for numeric styles)
/// - year-suffix: Year suffix for disambiguation
/// - position: Citation position ("first", "subsequent", "ibid", "ibid-with-locator")
/// - suppress-affixes: If true, don't apply prefix/suffix (for multi-cite contexts)
/// - first-note-number: Note number where this citation first appeared (for ibid/subsequent)
/// Returns: Typst content
#let render-citation(
  entry,
  style,
  form: none,
  supplement: none,
  cite-number: none,
  year-suffix: "",
  position: "first",
  suppress-affixes: false,
  first-note-number: none,
  abbreviations: (:),
) = {
  let ctx = create-context(
    style,
    entry,
    cite-number: cite-number,
    abbreviations: abbreviations,
  )
  let ctx = (
    ..ctx,
    year-suffix: year-suffix,
    position: position,
    first-reference-note-number: if first-note-number != none {
      str(first-note-number)
    } else { "" },
  )

  let citation = style.citation
  if citation == none or citation.layout == none {
    return text(fill: red, "[No citation layout]")
  }

  let layout = citation.layout

  // Interpret citation layout
  let result = layout
    .children
    .map(node => interpret-node(node, ctx))
    .filter(x => x != [] and x != "")
    .join(layout.delimiter)

  // Handle form variations
  if form == "author" {
    // Extract author only - use standard name formatter
    let names = ctx.parsed-names.at("author", default: ())
    if names.len() > 0 {
      // Use default name formatting attributes
      let name-attrs = (
        form: "long",
        name-as-sort-order: none,
        sort-separator: ", ",
        delimiter: ", ",
        "and": "text",
      )
      format-names(names, name-attrs, ctx)
    } else {
      "?"
    }
  } else if form == "year" {
    let year = ctx.fields.at("year", default: "n.d.")
    str(year) + year-suffix
  } else if form == "prose" {
    // Prose form: inline text without superscript/subscript
    let full-result = if supplement != none {
      [#result, #supplement]
    } else {
      result
    }

    // Apply prefix/suffix but NOT vertical-align (unless suppressed for multi-cite)
    if suppress-affixes {
      full-result
    } else {
      let prefix = layout.prefix
      let suffix = layout.suffix
      [#prefix#full-result#suffix]
    }
  } else {
    // Default form: apply all formatting
    let full-result = if supplement != none {
      [#result, #supplement]
    } else {
      result
    }

    // Apply prefix/suffix (unless suppressed for multi-cite)
    let prefix = if suppress-affixes { "" } else { layout.prefix }
    let suffix = if suppress-affixes { "" } else { layout.suffix }
    let formatted = [#prefix#full-result#suffix]

    // Apply vertical-align (superscript/subscript)
    let valign = layout.at("vertical-align", default: none)
    if valign == "sup" {
      super(formatted)
    } else if valign == "sub" {
      sub(formatted)
    } else {
      formatted
    }
  }
}

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
/// Returns: Array of (entry-ir, rendered, rendered-body, rendered-number, label) tuples
#let get-rendered-entries(bib-data, citations, style, abbreviations: (:)) = {
  let entries = process-entries(bib-data, citations, style)

  entries.map(e => (
    ir: e,
    rendered: render-entry-ir(
      e,
      style,
      include-number: true,
      abbreviations: abbreviations,
    ),
    rendered-body: render-entry-ir(
      e,
      style,
      include-number: false,
      abbreviations: abbreviations,
    ),
    rendered-number: render-citation-number(
      e.entry,
      style,
      cite-number: e.order,
    ),
    label: label("citeproc-ref-" + e.key),
  ))
}

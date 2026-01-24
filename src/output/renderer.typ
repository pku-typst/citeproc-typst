// citeproc-typst - Entry and Citation Renderer
//
// High-level rendering functions with IR pipeline integration.

#import "../interpreter/mod.typ": create-context, interpret-node
#import "punctuation.typ": collapse-punctuation
#import "../parsing/locales.typ": (
  create-fallback-locale, detect-language, locale-matches,
)
#import "../text/names.typ": format-names
#import "../core/state.typ": (
  create-entry-ir, get-entry-year, get-first-author-family,
)
#import "../data/sorting.typ": sort-bibliography-entries
#import "../data/disambiguation.typ": apply-disambiguation

/// Find first cs:names element in a node tree (recursive)
///
/// CSL spec: "The comparison is limited to the output of the (first) cs:names element"
#let find-first-names-node(node) = {
  if type(node) != dictionary { return none }

  let tag = node.at("tag", default: "")
  if tag == "names" { return node }

  let children = node.at("children", default: ())
  for child in children {
    let found = find-first-names-node(child)
    if found != none { return found }
  }
  none
}

/// Extract plain text from content recursively
#let content-to-string(c) = {
  if c == none or c == [] { return "" }
  if type(c) == str { return c }
  if type(c) == int or type(c) == float { return str(c) }

  // For content, try to get its text representation
  // This handles sequences, text nodes, etc.
  let text-func = c.func()
  let fields = c.fields()

  if text-func == text {
    // Text node - extract the body
    let body = fields.at("body", default: fields.at("text", default: ""))
    if type(body) == str { body } else { content-to-string(body) }
  } else if "children" in fields {
    // Sequence or container with children
    fields.children.map(content-to-string).join("")
  } else if "body" in fields {
    // Container with body
    content-to-string(fields.body)
  } else if "child" in fields {
    // Container with single child
    content-to-string(fields.child)
  } else if "text" in fields {
    // Direct text field
    if type(fields.text) == str { fields.text } else {
      content-to-string(fields.text)
    }
  } else {
    // Fallback: just return empty string for unknown content types
    ""
  }
}

/// Render the first cs:names element for cite grouping comparison
///
/// CSL spec: "cites with identical rendered names are grouped together...
/// The comparison is limited to the output of the (first) cs:names element,
/// but includes output rendered through cs:substitute."
///
/// - entry: Bibliography entry
/// - style: Parsed CSL style
/// - disambig-state: Disambiguation state (names-expanded, givenname-level)
/// Returns: String representation of rendered names for grouping comparison
#let render-names-for-grouping(
  entry,
  style,
  names-expanded: 0,
  givenname-level: 0,
) = {
  let citation = style.at("citation", default: none)
  if citation == none { return "" }

  let layout = citation.at("layout", default: none)
  if layout == none { return "" }

  // Find first cs:names element in citation layout
  let names-node = find-first-names-node(layout)
  if names-node == none { return "" }

  // Create context for rendering
  let ctx = create-context(style, entry)
  let ctx = (
    ..ctx,
    names-expanded: names-expanded,
    givenname-level: givenname-level,
  )

  // Render the names node
  let rendered = interpret-node(names-node, ctx)

  // Convert content to string for comparison
  content-to-string(rendered)
}

/// Get the first cs:names node in bibliography layout
///
/// - style: Parsed CSL style
/// Returns: The first cs:names node, or none
#let get-first-bib-names-node(style) = {
  let bib = style.at("bibliography", default: none)
  if bib == none { return none }

  let layouts = bib.at("layouts", default: ())
  if layouts.len() == 0 { return none }

  // Use the first layout (typically the default/fallback layout)
  let layout = layouts.first()
  find-first-names-node(layout)
}

/// Render the first cs:names element in bibliography for author substitution comparison
///
/// CSL spec for subsequent-author-substitute:
/// "Substitution is limited to the names of the first cs:names element rendered."
///
/// - entry: Bibliography entry
/// - style: Parsed CSL style
/// - names-expanded: Name expansion level for disambiguation
/// - givenname-level: Given name expansion level
/// Returns: String representation of rendered names for comparison
#let render-names-for-bibliography(
  entry,
  style,
  names-expanded: 0,
  givenname-level: 0,
) = {
  let names-node = get-first-bib-names-node(style)
  if names-node == none { return "" }

  // Create context for rendering
  let ctx = create-context(style, entry)
  let ctx = (
    ..ctx,
    names-expanded: names-expanded,
    givenname-level: givenname-level,
    render-context: "bibliography",
  )

  // Render the names node
  let rendered = interpret-node(names-node, ctx)

  // Convert content to string for comparison
  content-to-string(rendered)
}

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
  // CSL-M: Set render-context (citation-number is used in bibliography)
  let ctx = (..ctx, render-context: "bibliography")
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
/// - author-substitute: String to replace author names with (for subsequent-author-substitute)
/// - author-substitute-rule: Rule for how to substitute
/// - substitute-vars: Variable names of the first cs:names to substitute
/// Returns: Typst content
#let render-entry(
  entry,
  style,
  cite-number: none,
  year-suffix: "",
  include-number: true,
  abbreviations: (:),
  names-expanded: 0,
  givenname-level: 0,
  needs-disambiguate: false,
  author-substitute: none,
  author-substitute-rule: "complete-all",
  substitute-vars: "author",
) = {
  let ctx = create-context(
    style,
    entry,
    cite-number: cite-number,
    abbreviations: abbreviations,
    disambiguate: needs-disambiguate,
  )

  // Inject year suffix and disambiguation info into context for rendering
  // CSL-M: Set render-context for context condition
  // Also add author-substitute info for bibliography grouping
  let ctx = (
    ..ctx,
    year-suffix: year-suffix,
    names-expanded: names-expanded,
    givenname-level: givenname-level,
    render-context: "bibliography",
    author-substitute: author-substitute,
    author-substitute-rule: author-substitute-rule,
    substitute-vars: substitute-vars, // Variables from first cs:names element
  )

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

  // CSL-M: Switch locale if layout has explicit locale attribute
  let layout-locale = layout.at("locale", default: none)
  if layout-locale != none {
    let locales = style.at("locales", default: (:))
    let locale-code = layout-locale.split(" ").first()
    // Try exact match, then prefix match
    let target-locale = locales.at(locale-code, default: none)
    if target-locale == none {
      let prefix = if locale-code.len() >= 2 { locale-code.slice(0, 2) } else {
        locale-code
      }
      target-locale = locales.at(prefix, default: none)
    }
    if target-locale != none {
      ctx = (..ctx, locale: target-locale)
    }
  }
  // Fallback layout (no locale attr) uses style's default-locale (ctx.locale unchanged)

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

  // Apply punctuation collapsing to CSL output only
  collapse-punctuation([#result#layout-suffix])
}

/// Render a bibliography entry from an entry IR
///
/// - entry-ir: Entry IR with disambig info
/// - style: Parsed CSL style
/// - include-number: Whether to include citation number in output
/// - abbreviations: Optional abbreviation lookup table
/// - author-substitute: String to replace author names with (for subsequent-author-substitute)
/// - author-substitute-rule: Rule for how to substitute
/// - substitute-vars: Variable names of the first cs:names to substitute
/// Returns: Typst content
#let render-entry-ir(
  entry-ir,
  style,
  include-number: true,
  abbreviations: (:),
  author-substitute: none,
  author-substitute-rule: "complete-all",
  substitute-vars: "author",
) = {
  let disambig = entry-ir.disambig
  render-entry(
    entry-ir.entry,
    style,
    cite-number: entry-ir.order,
    year-suffix: disambig.at("year-suffix", default: ""),
    include-number: include-number,
    abbreviations: abbreviations,
    names-expanded: disambig.at("names-expanded", default: 0),
    givenname-level: disambig.at("givenname-level", default: 0),
    needs-disambiguate: disambig.at("needs-disambiguate", default: false),
    author-substitute: author-substitute,
    author-substitute-rule: author-substitute-rule,
    substitute-vars: substitute-vars,
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
  names-expanded: 0,
  givenname-level: 0,
) = {
  let ctx = create-context(
    style,
    entry,
    cite-number: cite-number,
    abbreviations: abbreviations,
  )

  let citation = style.citation
  if citation == none or citation.at("layouts", default: ()).len() == 0 {
    return text(fill: red, "[No citation layout]")
  }

  // CSL-M: Set render-context for context condition
  // Also pass et-al-subsequent settings for subsequent cites
  let ctx = (
    ..ctx,
    year-suffix: year-suffix,
    position: position,
    first-reference-note-number: if first-note-number != none {
      str(first-note-number)
    } else { "" },
    // Disambiguation state for name rendering
    names-expanded: names-expanded,
    givenname-level: givenname-level,
    render-context: "citation",
    // Et-al settings for subsequent cites (CSL spec: inheritable name options)
    et-al-subsequent-min: citation.at("et-al-subsequent-min", default: none),
    et-al-subsequent-use-first: citation.at(
      "et-al-subsequent-use-first",
      default: none,
    ),
    citation-et-al-min: citation.at("et-al-min", default: none),
    citation-et-al-use-first: citation.at("et-al-use-first", default: none),
  )

  // CSL-M: Select layout based on entry language
  let entry-lang = detect-language(entry.at("fields", default: (:)))
  let layout = select-layout(citation.layouts, entry-lang)

  // CSL-M: Switch locale if layout has explicit locale attribute
  let layout-locale = layout.at("locale", default: none)
  if layout-locale != none {
    let locales = style.at("locales", default: (:))
    let locale-code = layout-locale.split(" ").first()
    let target-locale = locales.at(locale-code, default: none)
    if target-locale == none {
      let prefix = if locale-code.len() >= 2 { locale-code.slice(0, 2) } else {
        locale-code
      }
      target-locale = locales.at(prefix, default: none)
    }
    if target-locale != none {
      ctx = (..ctx, locale: target-locale)
    }
  }

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

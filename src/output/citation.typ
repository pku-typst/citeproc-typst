// citrus - Citation Rendering Module
//
// Functions for rendering in-text citations.

#import "../core/constants.typ": POSITION, RENDER-CONTEXT
#import "../core/formatting.typ": apply-formatting
#import "../interpreter/mod.typ": create-context
#import "../interpreter/stack.typ": interpret-children-stack
#import "../parsing/mod.typ": detect-language
#import "../text/names.typ": format-names
#import "layout.typ": select-layout

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
/// - needs-disambiguate: If true, disambiguate condition returns true (CSL method 3)
/// Returns: Typst content
#let render-citation(
  entry,
  style,
  form: none,
  supplement: none,
  locator-label: "page",
  cite-number: none,
  year-suffix: none,
  position: POSITION.first,
  suppress-affixes: false,
  suppress-author: false,
  suppress-year: false,
  first-note-number: none,
  abbreviations: (:),
  names-expanded: 0,
  givenname-level: 0,
  needs-disambiguate: false,
) = {
  let ctx = create-context(
    style,
    entry,
    cite-number: cite-number,
    abbreviations: abbreviations,
    disambiguate: needs-disambiguate,
  )

  // Set suppress flags in context for CSL interpreter
  if suppress-author {
    ctx = (..ctx, suppress-author: true)
  }
  if suppress-year {
    ctx = (..ctx, suppress-year: true)
  }

  // Inject locator into fields if provided
  // CSL spec: locator is rendered via <text variable="locator"/>
  // Supports both structured locator (via metadata) and plain content
  // Also extract citation-item prefix/suffix if present
  let cite-item-prefix = ""
  let cite-item-suffix = ""

  if supplement != none {
    let parsed-label = locator-label
    let parsed-value = ""

    if type(supplement) == content {
      // Check if it's a structured locator (metadata wrapper)
      let sup-repr = repr(supplement)
      if (
        sup-repr.starts-with("metadata(")
          and sup-repr.contains("_citrus-locator")
      ) {
        // Extract dictionary from metadata content
        let fields = supplement.fields()
        if "value" in fields {
          let dict = fields.value
          if type(dict) == dictionary {
            parsed-label = dict.at("label", default: "page")
            parsed-value = str(dict.at("value", default: ""))
            // Extract citation-item level prefix/suffix
            cite-item-prefix = dict.at("prefix", default: "")
            cite-item-suffix = dict.at("suffix", default: "")
          }
        }
      } else {
        // Plain content - convert to string, use default label
        parsed-value = sup-repr
          .replace("\"", "")
          .replace("[", "")
          .replace("]", "")
      }
    } else {
      parsed-value = str(supplement)
    }

    // Trim whitespace from locator value
    let trimmed-value = parsed-value.trim()
    if trimmed-value != "" {
      ctx.fields.insert("locator", trimmed-value)
      ctx = (..ctx, locator-label: parsed-label)
    }
  }

  let citation = style.citation
  if citation == none or citation.at("layouts", default: ()).len() == 0 {
    return text(fill: red, "[No citation layout]")
  }

  // CSL-M: Set render-context for context condition
  // Also pass et-al-subsequent settings for subsequent cites
  // CSL spec: has-explicit-year-suffix determines if year-suffix is auto-appended to dates
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
    render-context: RENDER-CONTEXT.citation,
    // Et-al settings for subsequent cites (CSL spec: inheritable name options)
    et-al-subsequent-min: citation.at("et-al-subsequent-min", default: none),
    et-al-subsequent-use-first: citation.at(
      "et-al-subsequent-use-first",
      default: none,
    ),
    citation-et-al-min: citation.at("et-al-min", default: none),
    citation-et-al-use-first: citation.at("et-al-use-first", default: none),
    // Name formatting options (inheritable from citation level)
    citation-and: citation.at("and", default: none),
    citation-name-delimiter: citation.at("name-delimiter", default: none),
    citation-delimiter-precedes-et-al: citation.at(
      "delimiter-precedes-et-al",
      default: none,
    ),
    citation-delimiter-precedes-last: citation.at(
      "delimiter-precedes-last",
      default: none,
    ),
    has-explicit-year-suffix: citation.at(
      "has-explicit-year-suffix",
      default: false,
    ),
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

  // Interpret citation layout using stack-based interpreter with memoization
  // NOTE: layout.delimiter is for separating multiple cites within a citation,
  // NOT for separating elements within the layout. Don't pass it here.
  let result = interpret-children-stack(
    layout.children,
    ctx,
    delimiter: "",
  )

  // Apply citation-item level prefix/suffix (from locator metadata)
  // CSL spec: these go INSIDE the layout prefix/suffix
  if cite-item-prefix != "" or cite-item-suffix != "" {
    result = [#cite-item-prefix#result#cite-item-suffix]
  }

  // Handle form variations
  let final-result = if form == "author" {
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
    // Note: locator is now rendered via CSL's <text variable="locator"/>,
    // so we don't manually append supplement here anymore

    // Apply prefix/suffix but NOT vertical-align (unless suppressed for multi-cite)
    let formatted = if suppress-affixes {
      result
    } else {
      let prefix = layout.prefix
      let suffix = layout.suffix
      [#prefix#result#suffix]
    }

    // Apply font formatting only when not suppressed
    // (multicite applies layout formatting at the outer level)
    if suppress-affixes {
      formatted
    } else {
      apply-formatting(formatted, layout)
    }
  } else {
    // Default form: apply all formatting
    // Note: locator is now rendered via CSL's <text variable="locator"/>

    // When suppress-affixes is true, return raw result for multicite to wrap
    if suppress-affixes {
      result
    } else {
      // Apply prefix/suffix
      let prefix = layout.prefix
      let suffix = layout.suffix
      let formatted = [#prefix#result#suffix]

      // Apply vertical-align (superscript/subscript)
      let valign = layout.at("vertical-align", default: none)
      let with-valign = if valign == "sup" {
        super(formatted)
      } else if valign == "sub" {
        sub(formatted)
      } else {
        formatted
      }

      // Apply font formatting (font-weight, font-style)
      apply-formatting(with-valign, layout)
    }
  }

  final-result
}

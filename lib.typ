// citeproc-typst - CSL (Citation Style Language) processor for Typst
//
// Usage:
//   #import "@preview/citeproc-typst:0.1.0": init-csl, csl-bibliography
//   #show: init-csl.with(
//     read("refs.bib"),
//     read("style.csl"),
//   )
//   Use @key in text to cite...
//   #csl-bibliography()

#import "src/parser.typ": parse-csl, parse-locale-file
#import "src/interpreter.typ": create-context, interpret-node
#import "src/renderer.typ": (
  get-rendered-entries, process-entries, render-citation, render-entry,
)
#import "src/state.typ": (
  _bib-data, _config, _csl-style, cite-marker, collect-citations,
  get-entry-year, get-first-author-family,
)

// Counter for tracking citation occurrence index (for ibid detection)
#let _cite-occurrence = counter("citeproc-occurrence")
#import "src/disambiguation.typ": compute-year-suffixes
#import "src/locales.typ": detect-language
#import "src/collapsing.typ": apply-collapse, collapse-numeric-ranges

// =============================================================================
// Precomputation Cache (Performance Optimization)
// =============================================================================
// Instead of each @key recomputing all citations and year suffixes O(N) times,
// we precompute once at document end and store as queryable metadata.

/// Query precomputed citation data
/// Returns: (citations: ..., suffixes: ...) or none if not yet computed
#let _get-precomputed() = {
  let results = query(<citeproc-precomputed>)
  if results.len() > 0 {
    results.first().value
  } else {
    none
  }
}

/// Load and parse an external CSL locale file
///
/// - locale-content: Locale XML content (use `read("locales-en-US.xml")`)
/// Returns: Parsed locale object
#let load-locale(locale-content) = {
  parse-locale-file(locale-content)
}

/// Load and parse a CSL style file
///
/// - csl-content: CSL file content (use `read("style.csl")`)
/// - locales: Optional dict of lang -> locale content for external locales
///            e.g., (en-US: read("locales-en-US.xml"))
/// Returns: Parsed CSL style object
#let load-csl(csl-content, locales: (:)) = {
  // Parse external locales
  let parsed-locales = (:)
  for (lang, content) in locales.pairs() {
    parsed-locales.insert(lang, parse-locale-file(content))
  }

  let xml-tree = xml(bytes(csl-content))
  parse-csl(xml-tree, external-locales: parsed-locales)
}

/// Initialize the CSL citation system
///
/// - bib: BibTeX file content (use `read("refs.bib")`)
/// - style: CSL file content (use `read("style.csl")`)
/// - locales: Optional dict of lang -> locale content for external locales
/// - show-url: Whether to show URLs in bibliography
/// - show-doi: Whether to show DOIs in bibliography
/// - show-accessed: Whether to show access dates in bibliography
/// - doc: Document content
#let init-csl(
  bib,
  style,
  locales: (:),
  show-url: true,
  show-doi: true,
  show-accessed: true,
  doc,
) = {
  import "@preview/citegeist:0.2.1": load-bibliography

  // Load bibliography data
  let bib-data = load-bibliography(bib)
  _bib-data.update(bib-data)

  // Parse CSL style with external locales
  let csl-style = load-csl(style, locales: locales)
  _csl-style.update(csl-style)

  // Set display config
  _config.update((
    show-url: show-url,
    show-doi: show-doi,
    show-accessed: show-accessed,
  ))

  // Intercept cite elements
  show cite: it => {
    let key = str(it.key)

    // Place citation marker for collection
    cite-marker(key, locator: it.supplement)

    // Step occurrence counter to track which citation this is
    _cite-occurrence.step()

    // Render citation using precomputed data (O(1) lookup instead of O(N) recomputation)
    context {
      let bib = _bib-data.get()
      let style = _csl-style.get()
      let entry = bib.at(key, default: none)

      if entry == none {
        text(fill: red, "[??" + key + "??]")
      } else {
        // Query precomputed data (computed once at document end)
        let precomputed = _get-precomputed()

        // Get citation info from precomputed cache
        let citations = precomputed.citations
        let suffixes = precomputed.suffixes

        let cite-number = citations.order.at(key, default: citations.count + 1)

        // Get current occurrence index (0-based)
        let occurrence-idx = _cite-occurrence.get().first() - 1

        // Position tracking for subsequent/ibid
        let all-positions = citations.positions.at(key, default: ())
        let position = all-positions.find(p => (
          p.at("index", default: -1) == occurrence-idx
        ))
        let position = if position != none {
          position.at("position", default: "first")
        } else if all-positions.len() == 0 {
          "first"
        } else {
          if all-positions.len() <= 1 { "first" } else { "subsequent" }
        }

        // Get year suffix from precomputed cache (O(1) lookup)
        let year-suffix = suffixes.at(key, default: "")

        let result = render-citation(
          entry,
          style,
          form: it.form,
          supplement: it.supplement,
          cite-number: cite-number,
          year-suffix: year-suffix,
          position: position,
        )

        // Note styles: wrap in footnote (unless prose/author/year form)
        let is-note-style = style.class == "note"
        let is-inline-form = it.form in ("prose", "author", "year")

        if is-note-style and not is-inline-form {
          footnote(link(label("citeproc-ref-" + key), result))
        } else {
          link(label("citeproc-ref-" + key), result)
        }
      }
    }
  }

  doc

  // Hidden bibliography for @key syntax (at end to avoid blank page)
  {
    set bibliography(title: none)
    show bibliography: none
    bibliography(bytes(bib))
  }

  // Precompute citation data ONCE at document end
  // This is queried by each @key citation via _get-precomputed()
  // Performance: O(N) once instead of O(N²) across all citations
  context {
    let bib = _bib-data.get()
    let style = _csl-style.get()
    let citations = collect-citations()

    // Compute year suffixes once for all entries
    let entries-ir = citations
      .order
      .pairs()
      .map(((k, order)) => {
        let e = bib.at(k, default: none)
        if e == none { return none }
        (key: k, entry: e, order: order)
      })
      .filter(x => x != none)

    let suffixes = compute-year-suffixes(entries-ir, style)

    // Store as queryable metadata
    [#metadata((
      citations: citations,
      suffixes: suffixes,
    ))<citeproc-precomputed>]
  }
}

/// Get cited entries with rich metadata (low-level API)
///
/// Returns an array of entries, each containing:
/// - `key`: Citation key
/// - `order`: Citation order (for numeric styles)
/// - `year-suffix`: Year disambiguation suffix (e.g., "a", "b")
/// - `lang`: Detected language ("zh" or "en")
/// - `entry-type`: Entry type ("article", "book", etc.)
/// - `fields`: Raw field dictionary (title, author, year, ...)
/// - `parsed-names`: Parsed author/editor names
/// - `rendered`: CSL-rendered content (full, may contain citation number)
/// - `rendered-body`: CSL-rendered content (without citation number, for custom rendering)
/// - `ref-label`: Label object for linking
/// - `labeled-rendered`: Rendered content with label attached
///
/// Usage:
/// ```typst
/// context {
///   let entries = get-cited-entries()
///   for e in entries {
///     // Option 1: Use labeled-rendered directly
///     e.labeled-rendered
///     // Option 2: Custom content + label
///     [Custom: #e.fields.at("title") #e.ref-label]
///   }
/// }
/// ```
#let get-cited-entries() = {
  let bib = _bib-data.get()
  let style = _csl-style.get()

  // Use precomputed data when available
  let precomputed = _get-precomputed()
  let citations = precomputed.citations

  // Process entries through IR pipeline
  let rendered-entries = get-rendered-entries(bib, citations, style)

  // Build rich entry data
  rendered-entries.map(e => (
    key: e.ir.key,
    order: e.ir.order,
    year-suffix: e.ir.disambig.year-suffix,
    lang: detect-language(e.ir.entry.at("fields", default: (:))),
    entry-type: e.ir.entry.at("entry_type", default: "misc"),
    fields: e.ir.entry.at("fields", default: (:)),
    parsed-names: e.ir.entry.at("parsed_names", default: (:)),
    rendered: e.rendered,
    rendered-body: e.rendered-body, // Without citation number (for custom rendering)
    rendered-number: e.rendered-number, // Just the citation number (for alignment)
    ref-label: e.label,
    labeled-rendered: [#e.rendered #e.label],
  ))
}

/// Render the bibliography
///
/// - title: Bibliography title (auto, none, or custom content)
/// - full-control: Optional callback for custom rendering (entries => content)
///   - Signature: `(entries) => content`
///   - entries: Array from `get-cited-entries()`, each with:
///     - key, order, year-suffix, lang, entry-type
///     - fields, parsed-names, rendered, ref-label, labeled-rendered
///
/// Usage:
/// ```typst
/// // Standard usage
/// #csl-bibliography()
///
/// // Custom title
/// #csl-bibliography(title: heading(level: 2)[References])
///
/// // Full custom rendering
/// #csl-bibliography(full-control: entries => {
///   for e in entries [
///     [#e.order] #e.rendered #e.ref-label
///     #parbreak()
///   ]
/// })
/// ```
#let csl-bibliography(title: auto, full-control: none) = {
  context {
    let bib = _bib-data.get()
    let style = _csl-style.get()

    // Use precomputed data
    let precomputed = _get-precomputed()
    let citations = precomputed.citations

    // Auto title based on style locale
    let references-term = style.locale.terms.at("references", default: none)
    let references-text = if references-term != none {
      if type(references-term) == dictionary {
        references-term.at("multiple", default: "References")
      } else {
        references-term
      }
    } else {
      "References"
    }

    let actual-title = if title == auto {
      heading(numbering: none, references-text)
    } else {
      title
    }

    if actual-title != none {
      actual-title
    }

    // Get rich entry data
    let entries = get-cited-entries()

    // Allow full control if provided
    if full-control != none {
      full-control(entries)
    } else {
      // Check for second-field-align setting
      let bib-settings = style.at("bibliography", default: (:))
      let second-field-align = bib-settings.at(
        "second-field-align",
        default: none,
      )

      if second-field-align == "flush" {
        // Flush mode: number at margin, text follows inline
        // Wrapped lines indent to align with text start
        let max-order = entries.fold(0, (acc, e) => calc.max(acc, e.order))
        let digit-count = str(max-order).len()
        let num-width = 2em + digit-count * 0.6em
        let indent = num-width + 0.5em

        set par(first-line-indent: 0em, hanging-indent: indent, spacing: 0.65em)
        for e in entries {
          box(width: num-width, align(right, e.rendered-number))
          h(0.5em)
          [#e.rendered-body #e.ref-label]
          parbreak()
        }
      } else if second-field-align == "margin" {
        // Margin mode: number in left margin, text starts at margin
        // All lines (including first) start at the same position
        let max-order = entries.fold(0, (acc, e) => calc.max(acc, e.order))
        let digit-count = str(max-order).len()
        let num-width = 2em + digit-count * 0.6em + 0.5em

        set par(
          first-line-indent: -num-width,
          hanging-indent: 0em,
          spacing: 0.65em,
        )
        pad(left: num-width)[
          #for e in entries {
            box(width: num-width, align(right, e.rendered-number))
            [#e.rendered-body #e.ref-label]
            parbreak()
          }
        ]
      } else {
        // Default: simple hanging indent
        set par(hanging-indent: 2em, first-line-indent: 0em)
        for e in entries {
          e.labeled-rendered
          parbreak()
        }
      }
    }
  }
}

/// Create multiple citations at once
///
/// - keys: Citation keys (strings or dicts with key and supplement)
/// - form: Citation form ("prose" for narrative style)
/// Returns: Combined citation content
#let multicite(..args) = {
  let raw-list = args.pos()
  let form = args.named().at("form", default: none)

  if raw-list.len() == 0 { return [] }

  // Normalize: convert strings to dicts
  let normalized = raw-list.map(item => {
    if type(item) == str {
      (key: item, supplement: none)
    } else {
      (key: item.at("key"), supplement: item.at("supplement", default: none))
    }
  })

  // Place markers for all keys
  for item in normalized {
    cite-marker(item.key, locator: item.supplement)
  }

  context {
    let bib = _bib-data.get()
    let style = _csl-style.get()

    // Use precomputed data (O(1) lookup)
    let precomputed = _get-precomputed()
    let citations = precomputed.citations
    let suffixes = precomputed.suffixes

    // Detect style class
    let is-note-style = style.class == "note"
    let is-author-date = (
      style.class == "in-text"
        and (
          style.citation.at("disambiguate-add-year-suffix", default: false)
            or style.citation.layout.prefix == "("
        )
    )

    // Get layout config
    let prefix = style.citation.layout.prefix
    let suffix = style.citation.layout.suffix
    let delimiter = style.citation.layout.delimiter

    let first-key = normalized.first().key

    if is-note-style {
      // Note/footnote style: render each citation fully and join with delimiter
      // Wrap in footnote unless using prose/author/year form
      import "src/renderer.typ": render-citation

      let cite-parts = normalized.map(item => {
        let entry = bib.at(item.key, default: none)
        if entry == none { return [] }
        render-citation(
          entry,
          style,
          supplement: item.supplement,
          form: if form != none { form } else { "full" },
        )
      })

      let result = cite-parts.filter(p => p != []).join(delimiter)
      let linked = link(label("citeproc-ref-" + first-key), result)

      // Wrap in footnote unless using inline forms
      let is-inline-form = form in ("prose", "author", "year")
      if is-inline-form {
        linked
      } else {
        footnote(linked)
      }
    } else if is-author-date {
      // Author-date style: format as "(Author1, Year1; Author2, Year2)"
      // Get collapse mode from citation style
      let collapse-mode = style.citation.at("collapse", default: none)

      // Use precomputed suffixes (O(1) lookup instead of O(N) recomputation)

      // Build items with author, year, suffix
      let cite-items = normalized
        .map(item => {
          let entry = bib.at(item.key, default: none)
          if entry == none { return none }

          let author = get-first-author-family(entry)
          let year = get-entry-year(entry)
          let suffix = suffixes.at(item.key, default: "")

          (
            key: item.key,
            author: author,
            year: year,
            suffix: suffix,
            supplement: item.supplement,
            order: citations.order.at(item.key, default: 0),
          )
        })
        .filter(x => x != none)

      // Get delimiters from style
      let cite-group-delim = style.citation.at(
        "cite-group-delimiter",
        default: ", ",
      )
      let year-suffix-delim = style.citation.at(
        "year-suffix-delimiter",
        default: ", ",
      )
      let after-collapse-delim = style.citation.at(
        "after-collapse-delimiter",
        default: "; ",
      )

      // Apply collapsing (year, year-suffix, or year-suffix-ranged)
      let result = if (
        collapse-mode in ("year", "year-suffix", "year-suffix-ranged")
      ) {
        apply-collapse(
          cite-items,
          collapse-mode,
          delimiter: "; ",
          cite-group-delimiter: cite-group-delim,
          year-suffix-delimiter: year-suffix-delim,
          after-collapse-delimiter: after-collapse-delim,
        )
      } else {
        // No collapsing or unknown mode - format each citation separately
        let parts = cite-items.map(it => {
          let year-str = str(it.year) + it.suffix
          if it.supplement != none {
            [#it.author, #year-str: #it.supplement]
          } else {
            [#it.author, #year-str]
          }
        })
        parts.join("; ")
      }

      // Apply vertical-align (superscript/subscript)
      let valign = style.citation.layout.at("vertical-align", default: none)

      if form == "prose" {
        // Prose: no outer parentheses
        link(label("citeproc-ref-" + first-key), result)
      } else {
        // Normal: with parentheses
        let formatted = [#prefix#result#suffix]
        let final-result = if valign == "sup" {
          super(formatted)
        } else if valign == "sub" {
          sub(formatted)
        } else {
          formatted
        }
        link(label("citeproc-ref-" + first-key), final-result)
      }
    } else {
      // Numeric style: format as "[1, 2, 3]" or "[1-3]"
      // Get collapse mode from citation style
      let collapse-mode = style.citation.at("collapse", default: none)

      // Build items with order numbers
      let cite-items = normalized.map(item => {
        let order = citations.order.at(item.key, default: 0)
        (
          key: item.key,
          order: order,
          supplement: item.supplement,
        )
      })

      // Apply collapsing
      let result = apply-collapse(
        cite-items,
        collapse-mode,
        delimiter: delimiter,
        cite-group-delimiter: style.citation.at(
          "cite-group-delimiter",
          default: ", ",
        ),
        year-suffix-delimiter: style.citation.at(
          "year-suffix-delimiter",
          default: ", ",
        ),
        after-collapse-delimiter: style.citation.at(
          "after-collapse-delimiter",
          default: none,
        ),
      )

      // Apply vertical-align (superscript/subscript)
      let valign = style.citation.layout.at("vertical-align", default: none)
      let formatted = [#prefix#result#suffix]
      let final-result = if valign == "sup" {
        super(formatted)
      } else if valign == "sub" {
        sub(formatted)
      } else {
        formatted
      }
      link(label("citeproc-ref-" + first-key), final-result)
    }
  }
}

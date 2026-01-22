// citeproc-typst - CSL Node Interpreter
//
// Interprets CSL AST nodes and produces Typst content.
// Uses a dispatch table for clean, extensible tag handling.

#import "variables.typ": get-variable, has-variable
#import "conditions.typ": eval-condition, eval-nested-conditions
#import "names.typ": format-names, format-names-with-institutions
#import "dates.typ": (
  format-date, format-date-part, format-date-with-form, parse-bibtex-date,
)
#import "locales.typ": lookup-term
#import "ranges.typ": format-page-range
#import "quotes.typ": apply-quotes

// =============================================================================
// Context Creation
// =============================================================================

/// Create interpretation context
/// - cite-number: Optional citation number to inject
#let create-context(style, entry, cite-number: none) = {
  let fields = entry.at("fields", default: (:))

  // Inject citation number if provided
  if cite-number != none {
    fields.insert("citation-number", str(cite-number))
  }

  // Map CSL name variables to BibTeX name fields
  let raw-names = entry.at("parsed_names", default: (:))
  let mapped-names = raw-names

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

  (
    style: style,
    entry: entry,
    macros: style.macros,
    locale: style.locale,
    fields: fields,
    parsed-names: mapped-names,
    entry-type: entry.at("entry_type", default: "misc"),
  )
}

// =============================================================================
// Utility Functions
// =============================================================================

/// Capitalize the first character of a string (Unicode-safe)
#let capitalize-first-char(s) = {
  if s.len() == 0 { return s }
  let chars = s.clusters()
  if chars.len() == 0 { return s }
  upper(chars.first()) + chars.slice(1).join()
}

/// Left-pad a string with zeros to a given width
#let zero-pad(s, width) = {
  let s = str(s)
  let padding = width - s.len()
  if padding > 0 {
    "0" * padding + s
  } else {
    s
  }
}

/// Strip periods from a string (CSL strip-periods="true")
/// Only removes periods after letters, preserves periods in numbers (e.g., "2.1.0")
#let strip-periods-from-str(s) = {
  if type(s) != str { return s }
  // Match period that follows a letter (including accented Latin letters)
  s.replace(regex("([a-zA-Z\u{00C0}-\u{024F}])\\."), m => m.captures.at(0))
}

/// Check if content is empty (handles strings, arrays, and content)
#let is-empty(x) = {
  if x == none { return true }
  if x == [] { return true }
  if type(x) == str { return x.trim() == "" }
  if type(x) == array { return x.len() == 0 }
  // For content, convert to string and check
  if type(x) == content {
    let fields = x.fields()
    if "children" in fields {
      return fields.children.len() == 0
    }
    if "text" in fields {
      return fields.text.trim() == ""
    }
    if "body" in fields {
      return is-empty(fields.body)
    }
    return repr(x) == "[]"
  }
  false
}

/// Strip trailing punctuation from content for delimiter collapsing
#let strip-trailing-punct(content) = {
  let s = repr(content)
  s.ends-with(".]") or s.ends-with(".])") or s.ends-with(".\"]")
}

/// Join parts with delimiter, collapsing duplicate punctuation
#let join-with-delimiter(parts, delimiter) = {
  if parts.len() == 0 { return [] }
  if parts.len() == 1 { return parts.first() }
  if delimiter == "" { return parts.join() }

  let delim-first = delimiter.first()
  let is-punct-delim = delim-first in (".", ",", ";", ":")

  if not is-punct-delim {
    return parts.join(delimiter)
  }

  // Join with punctuation collapsing
  let result = parts.first()
  for part in parts.slice(1) {
    if strip-trailing-punct(result) {
      let rest = if delimiter.len() > 1 { delimiter.slice(1) } else { "" }
      result = [#result#rest#part]
    } else {
      result = [#result#delimiter#part]
    }
  }
  result
}

// Minor words for title case (defined once, not per call)
#let _minor-words = (
  "a",
  "an",
  "the",
  "and",
  "but",
  "or",
  "for",
  "nor",
  "on",
  "at",
  "to",
  "from",
  "by",
  "of",
  "in",
)

/// Apply CSL formatting attributes to content
/// Optimized: extract all attrs at once, avoid repeated dictionary lookups
#let apply-formatting(content, attrs) = {
  if content == [] or content == "" { return content }
  if attrs.len() == 0 { return content }

  let result = content

  // Extract all formatting attrs at once (single dict traversal)
  let font-style = attrs.at("font-style", default: none)
  let font-weight = attrs.at("font-weight", default: none)
  let text-decoration = attrs.at("text-decoration", default: none)
  let font-variant = attrs.at("font-variant", default: none)
  let vertical-align = attrs.at("vertical-align", default: none)
  let text-case = attrs.at("text-case", default: none)
  let strip-periods = attrs.at("strip-periods", default: "false") == "true"

  // Strip periods if requested (CSL strip-periods="true")
  if strip-periods {
    result = strip-periods-from-str(result)
  }

  // Apply formatting in order
  if font-style == "italic" or font-style == "oblique" {
    result = emph(result)
  }

  if font-weight == "bold" {
    result = strong(result)
  } else if font-weight == "light" {
    result = text(weight: "light", result)
  }

  if text-decoration == "underline" {
    result = underline(result)
  }

  if font-variant == "small-caps" {
    result = smallcaps(result)
  }

  if vertical-align == "sup" {
    result = super(result)
  } else if vertical-align == "sub" {
    result = sub(result)
  }

  // text-case only works on strings
  if text-case != none and type(result) == str {
    if text-case == "lowercase" {
      result = lower(result)
    } else if text-case == "uppercase" {
      result = upper(result)
    } else if text-case == "capitalize-first" and result.len() > 0 {
      result = capitalize-first-char(result)
    } else if text-case == "capitalize-all" {
      result = result
        .split(" ")
        .map(w => if w.len() > 0 { capitalize-first-char(w) } else { w })
        .join(" ")
    } else if text-case == "title" {
      result = result
        .split(" ")
        .enumerate()
        .map(((i, w)) => {
          let lower-w = lower(w)
          if i == 0 or lower-w not in _minor-words {
            if w.len() > 0 { capitalize-first-char(w) } else { w }
          } else { lower-w }
        })
        .join(" ")
    }
  }

  // CSL-M display attribute: "block" creates a new line
  let display = attrs.at("display", default: none)
  if display == "block" {
    result = [#linebreak()#result]
  } else if display == "indent" {
    result = [#h(2em)#result]
  } else if display == "left-margin" {
    // Left margin display (used in some bibliography layouts)
    result = [#result]
  } else if display == "right-inline" {
    // Right inline (continuation after left-margin)
    result = [#result]
  }

  result
}

/// Wrap content with prefix/suffix and apply formatting
#let finalize(content, attrs) = {
  if is-empty(content) { return [] }

  // Strip periods before wrapping (CSL strip-periods="true")
  let processed = if attrs.at("strip-periods", default: "false") == "true" {
    strip-periods-from-str(content)
  } else {
    content
  }

  let prefix = attrs.at("prefix", default: "")
  let suffix = attrs.at("suffix", default: "")

  // Combine prefix + content + suffix without extra spacing
  // If content is a string, concatenate directly to avoid Typst inserting spaces
  let result = if type(processed) == str {
    prefix + processed + suffix
  } else {
    [#prefix#processed#suffix]
  }
  apply-formatting(result, attrs)
}

// =============================================================================
// Tag Handlers
// =============================================================================
// Each handler has signature: (node, ctx, interpret) -> content
// where `interpret` is the recursive interpret-node function

/// Handle <text> element
#let handle-text(node, ctx, interpret) = {
  let attrs = node.at("attrs", default: (:))

  let result = if "variable" in attrs {
    let var-name = attrs.variable
    let val = get-variable(ctx, var-name)

    if val != "" {
      // Apply page range formatting for page variables
      if var-name == "page" or var-name == "page-first" {
        let page-format = ctx.style.at("page-range-format", default: none)
        format-page-range(val, format: page-format, ctx: ctx)
      } else {
        val
      }
    } else { [] }
  } else if "macro" in attrs {
    let macro-name = attrs.macro
    let macro-def = ctx.macros.at(macro-name, default: none)
    if macro-def != none {
      macro-def
        .children
        .map(n => interpret(n, ctx))
        .filter(x => not is-empty(x))
        .join()
    } else { [] }
  } else if "value" in attrs {
    attrs.value
  } else if "term" in attrs {
    let form = attrs.at("form", default: "long")
    let plural = attrs.at("plural", default: "false") == "true"
    lookup-term(ctx, attrs.term, form: form, plural: plural)
  } else { [] }

  // Apply quotes if requested (CSL quotes="true")
  let quoted-result = if (
    attrs.at("quotes", default: "false") == "true" and not is-empty(result)
  ) {
    apply-quotes(result, ctx, level: 0)
  } else {
    result
  }

  finalize(quoted-result, attrs)
}

// =============================================================================
// CSL-M require/reject helpers (comma-safe locators)
// =============================================================================

/// Check if content ends with a number (for comma-safe detection)
#let _ends-with-number(content) = {
  let s = repr(content)
  // Check if the string representation ends with a digit
  s.match(regex("[0-9][\]\)]*$")) != none
}

/// Check if content starts with a "romanesque" (latin alphabet) term
#let _starts-with-latin(content) = {
  let s = repr(content)
  // Match if starts with a latin letter (not a symbol)
  s.match(regex("^[\[\(]*[a-zA-Z]")) != none
}

/// Evaluate CSL-M require/reject conditions
///
/// - require: "comma-safe" or "comma-safe-numbers-only"
/// - reject: same values (inverts the logic)
/// - ctx: Context with preceding-ends-with-number info
/// Returns: bool (true if group should render)
#let eval-comma-safe(require-val, reject-val, group-content, ctx) = {
  // Get preceding context info
  let preceding-ends-num = ctx.at("preceding-ends-with-number", default: false)
  let group-starts-latin = _starts-with-latin(group-content)

  let comma-safe-result = if (
    require-val == "comma-safe" or reject-val == "comma-safe"
  ) {
    // comma-safe is true when:
    // 1. Preceded by number AND (starts with latin term OR no term)
    // 2. Preceded by non-number AND starts with latin term
    if preceding-ends-num {
      true // Always comma-safe after number if we have content
    } else {
      group-starts-latin
    }
  } else if (
    require-val == "comma-safe-numbers-only"
      or reject-val == "comma-safe-numbers-only"
  ) {
    // Only true when preceded by a number
    preceding-ends-num
  } else {
    true // No require/reject, always render
  }

  // Apply require (must be true) or reject (must be false)
  if require-val != none {
    comma-safe-result
  } else if reject-val != none {
    not comma-safe-result
  } else {
    true
  }
}

/// Handle <group> element
/// Supports CSL-M require/reject for comma-safe locators
#let handle-group(node, ctx, interpret) = {
  let attrs = node.at("attrs", default: (:))
  let children = node.at("children", default: ())

  // CSL-M require/reject attributes
  let require-val = attrs.at("require", default: none)
  let reject-val = attrs.at("reject", default: none)

  // Collect renderable parts, flattening choose/if/else structures
  let collect-parts(nodes, ctx, interpret) = {
    let parts = ()
    for n in nodes {
      if type(n) != dictionary { continue }
      let child-tag = n.at("tag", default: "")
      let child-children = n.at("children", default: ())

      if child-tag == "choose" {
        // Flatten: collect parts from matching branch
        for branch in child-children {
          if type(branch) != dictionary { continue }
          let branch-tag = branch.at("tag", default: "")
          let branch-attrs = branch.at("attrs", default: (:))
          let branch-children = branch.at("children", default: ())

          if branch-tag == "if" or branch-tag == "else-if" {
            if eval-condition(branch-attrs, ctx) {
              for part in collect-parts(branch-children, ctx, interpret) {
                parts.push(part)
              }
              break
            }
          } else if branch-tag == "else" {
            for part in collect-parts(branch-children, ctx, interpret) {
              parts.push(part)
            }
            break
          }
        }
      } else {
        let result = interpret(n, ctx)
        if not is-empty(result) {
          parts.push(result)
        }
      }
    }
    parts
  }

  let parts = collect-parts(children, ctx, interpret)

  if parts.len() == 0 {
    []
  } else {
    let delimiter = attrs.at("delimiter", default: "")
    let prefix = attrs.at("prefix", default: "")
    let suffix = attrs.at("suffix", default: "")
    let joined = join-with-delimiter(parts, delimiter)
    let result = apply-formatting([#prefix#joined#suffix], attrs)

    // Apply CSL-M require/reject check
    if require-val != none or reject-val != none {
      if eval-comma-safe(require-val, reject-val, result, ctx) {
        result
      } else {
        []
      }
    } else {
      result
    }
  }
}

/// Handle <choose> element
/// Supports CSL-M nested cs:conditions
#let handle-choose(node, ctx, interpret) = {
  let children = node.at("children", default: ())

  for branch in children {
    if type(branch) != dictionary { continue }

    let branch-tag = branch.at("tag", default: "")
    let branch-attrs = branch.at("attrs", default: (:))
    let branch-children = branch.at("children", default: ())

    if branch-tag == "if" or branch-tag == "else-if" {
      // CSL-M extension: check for nested cs:conditions element
      let conditions-node = branch-children.find(c => (
        type(c) == dictionary and c.at("tag", default: "") == "conditions"
      ))

      let condition-met = if conditions-node != none {
        // Use nested conditions evaluation (CSL-M)
        eval-nested-conditions(conditions-node, ctx)
      } else {
        // Standard CSL condition evaluation
        eval-condition(branch-attrs, ctx)
      }

      if condition-met {
        // Filter out the conditions node from rendering
        return branch-children
          .filter(c => (
            type(c) != dictionary or c.at("tag", default: "") != "conditions"
          ))
          .map(n => interpret(n, ctx))
          .filter(x => not is-empty(x))
          .join()
      }
    } else if branch-tag == "else" {
      return branch-children
        .map(n => interpret(n, ctx))
        .filter(x => not is-empty(x))
        .join()
    }
  }
  []
}

/// Handle <names> element
#let handle-names(node, ctx, interpret) = {
  let attrs = node.at("attrs", default: (:))
  let children = node.at("children", default: ())
  let var-names = attrs.at("variable", default: "author").split(" ")

  // Try each variable in order
  let names = none
  let used-var = none
  for var-name in var-names {
    let candidate = ctx.parsed-names.at(var-name, default: ())
    if candidate.len() > 0 {
      names = candidate
      used-var = var-name
      break
    }
  }

  if names == none or names.len() == 0 {
    // Try substitute - CSL spec: try each child in order, use FIRST that produces output
    let substitute = children.find(c => (
      type(c) == dictionary and c.at("tag", default: "") == "substitute"
    ))
    if substitute != none {
      let sub-result = []
      for sub-child in substitute.at("children", default: ()) {
        let rendered = interpret(sub-child, ctx)
        if not is-empty(rendered) {
          sub-result = rendered
          break // Use first non-empty result only
        }
      }
      sub-result
    } else { [] }
  } else {
    // Find name formatting options
    let name-node = children.find(c => (
      type(c) == dictionary and c.at("tag", default: "") == "name"
    ))
    let name-attrs = if name-node != none {
      name-node.at("attrs", default: (:))
    } else { (:) }

    // Find institution formatting options (CSL-M extension)
    let institution-node = children.find(c => (
      type(c) == dictionary and c.at("tag", default: "") == "institution"
    ))
    let institution-attrs = if institution-node != none {
      institution-node.at("attrs", default: (:))
    } else { none }

    // Find label if present
    let label-node = children.find(c => (
      type(c) == dictionary and c.at("tag", default: "") == "label"
    ))
    let label-content = if label-node != none {
      let label-attrs = label-node.at("attrs", default: (:))
      let form = label-attrs.at("form", default: "long")
      let plural = names.len() > 1
      let term = lookup-term(ctx, used-var, form: form, plural: plural)
      // Only apply formatting if term is non-empty (to avoid prefix/suffix on empty content)
      if term == "" { [] } else { finalize(term, label-attrs) }
    } else { [] }

    // Format names (with institution support if cs:institution is present)
    let names-content = if institution-attrs != none {
      format-names-with-institutions(names, name-attrs, institution-attrs, ctx)
    } else {
      format-names(names, name-attrs, ctx)
    }

    // Combine with label
    let result = if label-content != [] {
      let label-position = if label-node != none {
        let label-idx = children.position(c => (
          type(c) == dictionary and c.at("tag", default: "") == "label"
        ))
        let name-idx = children.position(c => (
          type(c) == dictionary and c.at("tag", default: "") == "name"
        ))
        if label-idx != none and name-idx != none and label-idx < name-idx {
          "before"
        } else { "after" }
      } else { "after" }

      if label-position == "before" {
        [#label-content #names-content]
      } else {
        [#names-content#attrs.at("delimiter", default: ", ")#label-content]
      }
    } else { names-content }

    finalize(result, attrs)
  }
}

/// Handle <date> element
#let handle-date(node, ctx, interpret) = {
  let attrs = node.at("attrs", default: (:))
  let children = node.at("children", default: ())
  let variable = attrs.at("variable", default: "issued")

  // Parse date based on variable attribute
  let dt = if variable == "issued" {
    parse-bibtex-date(ctx.fields)
  } else if variable == "accessed" {
    // Parse urldate for accessed date
    let urldate = ctx.fields.at("urldate", default: "")
    if urldate != "" {
      parse-bibtex-date((year: urldate, date: urldate))
    } else { none }
  } else if variable == "original-date" {
    // Parse origdate for original-date
    let origdate = ctx.fields.at("origdate", default: "")
    if origdate != "" {
      parse-bibtex-date((year: origdate, date: origdate))
    } else { none }
  } else if variable == "event-date" {
    // Parse eventdate
    let eventdate = ctx.fields.at("eventdate", default: "")
    if eventdate != "" {
      parse-bibtex-date((year: eventdate, date: eventdate))
    } else { none }
  } else {
    // Default to issued
    parse-bibtex-date(ctx.fields)
  }

  // Check for date children (inline date-parts)
  let date-part-nodes = children.filter(c => (
    type(c) == dictionary and c.at("tag", default: "") == "date-part"
  ))

  if dt != none {
    let result = if date-part-nodes.len() > 0 {
      // Use inline date-part specifications
      let parts = ()
      for dp in date-part-nodes {
        let dp-attrs = dp.at("attrs", default: (:))
        let dp-name = dp-attrs.at("name", default: "")
        let dp-form = dp-attrs.at("form", default: "numeric")
        let dp-prefix = dp-attrs.at("prefix", default: "")
        let dp-suffix = dp-attrs.at("suffix", default: "")

        let formatted = format-date-part(dt, dp-name, dp-form, ctx)
        if formatted != "" {
          parts.push([#dp-prefix#formatted#dp-suffix])
        }
      }
      parts.join()
    } else {
      // Use form attribute or default
      let form = attrs.at("form", default: "numeric")
      let date-parts = attrs.at("date-parts", default: "year-month-day")
      format-date-with-form(dt, form, date-parts, ctx)
    }

    finalize(result, attrs)
  } else { [] }
}

/// Safely parse an integer from a string (returns none on failure)
#let safe-int(s) = {
  let s = str(s)
  // Extract leading digits only
  let m = s.match(regex("^-?\d+"))
  if m != none { int(m.text) } else { none }
}

/// Handle <number> element
#let handle-number(node, ctx, interpret) = {
  let attrs = node.at("attrs", default: (:))
  let var-name = attrs.at("variable", default: "")
  let val = get-variable(ctx, var-name)

  if not is-empty(val) {
    let form = attrs.at("form", default: "numeric")
    let num = safe-int(val)

    let result = if form == "ordinal" {
      if num != none {
        let ordinal-key = "ordinal-" + zero-pad(calc.rem(num, 100), 2)
        let suffix = lookup-term(ctx, ordinal-key, form: "long", plural: false)
        if suffix == "" or suffix == ordinal-key {
          let generic = lookup-term(ctx, "ordinal", form: "long", plural: false)
          str(num) + generic
        } else {
          str(num) + suffix
        }
      } else { val }
    } else if form == "long-ordinal" {
      if num != none and num >= 1 and num <= 10 {
        lookup-term(
          ctx,
          "long-ordinal-" + zero-pad(num, 2),
          form: "long",
          plural: false,
        )
      } else { val }
    } else if form == "roman" {
      if num != none and num > 0 {
        // Use Typst's built-in numbering for roman numerals
        numbering("i", num)
      } else { val }
    } else {
      // numeric (default)
      val
    }

    finalize(result, attrs)
  } else { [] }
}

/// Handle <label> element
#let handle-label(node, ctx, interpret) = {
  let attrs = node.at("attrs", default: (:))
  let var-name = attrs.at("variable", default: "")
  let form = attrs.at("form", default: "long")

  // Only render label if variable has value
  let val = get-variable(ctx, var-name)
  if is-empty(val) {
    []
  } else {
    // Determine plurality based on value content
    let val-str = if type(val) == str { val } else { "" }
    let plural = (
      val-str.contains("-")
        or val-str.contains(",")
        or val-str.contains("–")
        or val-str.contains(" ")
    )

    let result = lookup-term(ctx, var-name, form: form, plural: plural)
    finalize(result, attrs)
  }
}

/// Handle ignored child elements (processed by parent)
#let handle-noop(node, ctx, interpret) = []

/// Handle unknown elements (try to interpret children)
#let handle-unknown(node, ctx, interpret) = {
  let children = node.at("children", default: ())
  children.map(n => interpret(n, ctx)).filter(x => not is-empty(x)).join()
}

// =============================================================================
// Dispatch Table
// =============================================================================

/// Map tag names to handler functions
#let _tag-handlers = (
  "text": handle-text,
  "group": handle-group,
  "choose": handle-choose,
  "names": handle-names,
  "date": handle-date,
  "number": handle-number,
  "label": handle-label,
  // Child elements handled by parents
  "substitute": handle-noop,
  "name": handle-noop,
  "name-part": handle-noop,
  "institution": handle-noop,
  "date-part": handle-noop,
  "et-al": handle-noop,
)

// =============================================================================
// Main Interpreter
// =============================================================================

/// Interpret a single CSL node
///
/// - node: CSL AST node (dict with tag, attrs, children)
/// - ctx: Interpretation context
/// Returns: Typst content
#let interpret-node(node, ctx) = {
  // String nodes are literal text
  if type(node) == str {
    return node.trim()
  }

  // Skip non-element nodes
  if type(node) != dictionary {
    return []
  }

  let tag = node.at("tag", default: "")

  // Dispatch to handler
  let handler = _tag-handlers.at(tag, default: handle-unknown)
  handler(node, ctx, interpret-node)
}

// citrus - Compiler Runtime: Text/Variable

#import "../../core/mod.typ": apply-text-case, finalize, is-empty
#import "../../text/quotes.typ": apply-quotes, transform-quotes-at-level
#import "../../text/ranges.typ": format-page-range
#import "../../data/variables.typ": get-variable

/// Extract plain text from content recursively
#let _content-to-string(c) = {
  if c == none or c == [] { return "" }
  if type(c) == str { return c }
  if type(c) == int or type(c) == float { return str(c) }

  let fields = c.fields()
  let text-func = c.func()

  if text-func == text {
    let body = fields.at("body", default: fields.at("text", default: ""))
    if type(body) == str { body } else { _content-to-string(body) }
  } else if "children" in fields {
    fields.children.map(_content-to-string).join("")
  } else if "body" in fields {
    _content-to-string(fields.body)
  } else if "child" in fields {
    _content-to-string(fields.child)
  } else if "text" in fields {
    if type(fields.text) == str { fields.text } else {
      _content-to-string(fields.text)
    }
  } else {
    ""
  }
}

/// Get text variable value
///
/// - ctx: Context dictionary with fields and done-vars
/// - attrs: Dictionary of CSL attributes (variable, form, etc.)
/// Returns: (content, var-state, done-vars) tuple
#let get-text-variable(ctx, attrs) = {
  let var-name = attrs.at("variable", default: "")
  let form = attrs.at("form", default: "long")

  // Check if already rendered (done-vars quashing)
  if var-name in ctx.at("done-vars", default: ()) {
    return ([], "none", ())
  }

  // Special handling for year-suffix - it's in ctx, not ctx.fields
  if var-name == "year-suffix" {
    let suffix = ctx.at("year-suffix", default: none)
    if suffix != none and suffix != "" {
      import "../../data/collapsing.typ": num-to-suffix
      let suffix-str = if type(suffix) == int {
        num-to-suffix(suffix)
      } else {
        str(suffix)
      }
      return (finalize(suffix-str, attrs), "var", ())
    } else {
      return ([], "no-var", ())
    }
  }

  // Get value using get-variable which handles field name mapping
  let val = get-variable(ctx, var-name)

  // Handle short form
  let val = if form == "short" and val == "" {
    get-variable(ctx, var-name + "-short")
  } else { val }

  if val != "" {
    // Format page ranges for page, page-first, locator
    let formatted = if (
      var-name == "page" or var-name == "page-first" or var-name == "locator"
    ) {
      let page-format = if "style" in ctx {
        ctx.style.at("page-range-format", default: none)
      } else { none }
      format-page-range(val, format: page-format, ctx: ctx)
    } else { val }

    // Apply text-case FIRST while content is still a string
    let cased = apply-text-case(formatted, attrs, ctx: ctx)

    // Handle quotes (CSL quote flipflopping)
    let quote-level = ctx.at("quote-level", default: 0)
    let has-quotes = attrs.at("quotes", default: "false") == "true"

    // Normalize embedded quotes in content (only if ctx.style is available)
    let normalized = if type(cased) == str and "style" in ctx {
      if has-quotes {
        transform-quotes-at-level(cased, ctx, quote-level + 1)
      } else {
        transform-quotes-at-level(cased, ctx, quote-level)
      }
    } else { cased }

    // Apply quotes if requested (only if ctx.style is available)
    let quoted = if has-quotes and "style" in ctx {
      apply-quotes(normalized, ctx, level: quote-level)
    } else { normalized }

    (finalize(quoted, attrs), "var", ())
  } else {
    ([], "no-var", ())
  }
}

/// Apply text-case and quotes to generic text content
#let format-text-content(ctx, content, attrs) = {
  if is-empty(content) { return [] }

  let quote-level = ctx.at("quote-level", default: 0)
  let has-quotes = attrs.at("quotes", default: "false") == "true"

  let suffix = attrs.at("suffix", default: "")
  let punctuation-in-quote = if "style" in ctx {
    let locale = ctx.style.at("locale", default: (:))
    let options = locale.at("options", default: (:))
    options.at("punctuation-in-quote", default: false)
  } else { false }

  let quote-punct = if (
    has-quotes
      and punctuation-in-quote
      and suffix.len() > 0
      and suffix.first() in ("!", "?")
  ) {
    suffix.first()
  } else { "" }

  let adjusted-attrs = if quote-punct != "" {
    (..attrs, suffix: suffix.slice(1))
  } else {
    attrs
  }

  let processed = if type(content) == str {
    let value = if (
      quote-punct != "" and not content.ends-with(quote-punct)
    ) {
      content + quote-punct
    } else { content }
    let cased = apply-text-case(value, adjusted-attrs, ctx: ctx)
    let normalized = if has-quotes {
      transform-quotes-at-level(cased, ctx, quote-level + 1)
    } else {
      transform-quotes-at-level(cased, ctx, quote-level)
    }
    if has-quotes {
      apply-quotes(normalized, ctx, level: quote-level)
    } else { normalized }
  } else {
    content
  }

  let adjusted-attrs = if (
    adjusted-attrs.at("suffix", default: "").len() > 0
      and adjusted-attrs.at("suffix", default: "").first() == "."
      and _content-to-string(processed).ends-with(".")
  ) {
    let s = adjusted-attrs.at("suffix", default: "")
    (..adjusted-attrs, suffix: s.slice(1))
  } else {
    adjusted-attrs
  }

  finalize(processed, adjusted-attrs)
}

/// Format <text value="..."> with quotes/text-case
#let format-text-value(ctx, attrs) = {
  let value = attrs.at("value", default: "")
  let content = format-text-content(ctx, value, attrs)
  (content, "none", ())
}

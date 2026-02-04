// citrus - Compiler Runtime: Text/Variable

#import "../../core/mod.typ": apply-text-case, finalize
#import "../../text/quotes.typ": apply-quotes, transform-quotes-at-level
#import "../../text/ranges.typ": format-page-range
#import "../../data/variables.typ": get-variable

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

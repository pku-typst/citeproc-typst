// citeproc-typst - Text Handler
//
// Handles <text> CSL element.

#import "../core/mod.typ": finalize, is-empty
#import "../data/variables.typ": get-variable
#import "../parsing/locales.typ": lookup-term
#import "../text/ranges.typ": format-page-range
#import "../text/quotes.typ": apply-quotes

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
    // Check if we have precomputed results (memoization)
    let precomputed = ctx.at("macro-results", default: none)
    if precomputed != none and macro-name in precomputed {
      // Use precomputed result - O(1) lookup instead of recursive expansion
      precomputed.at(macro-name)
    } else {
      // Fallback to normal expansion (for sorting, etc.)
      let macro-def = ctx.macros.at(macro-name, default: none)
      if macro-def != none {
        macro-def
          .children
          .map(n => interpret(n, ctx))
          .filter(x => not is-empty(x))
          .join()
      } else { [] }
    }
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

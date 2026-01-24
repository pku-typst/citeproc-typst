// citeproc-typst - Number and Label Handlers
//
// Handles <number> and <label> CSL elements.

#import "../core/mod.typ": finalize, is-empty, zero-pad
#import "../data/variables.typ": get-variable
#import "../parsing/locales.typ": lookup-term

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

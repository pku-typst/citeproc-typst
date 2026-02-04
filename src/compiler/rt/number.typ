// citrus - Compiler Runtime: Number

#import "../../interpreter/number.typ": handle-number as _handle-number
#import "../../core/mod.typ": finalize, is-empty, safe-int, zero-pad
#import "../../parsing/mod.typ": lookup-term
#import "../../text/number.typ": get-ordinal-suffix
#import "../../data/variables.typ": get-variable

/// Format number from a CSL <number> element
#let format-number-numeric-compiled(ctx, attrs) = {
  let var-name = attrs.at("variable", default: "")
  let val = get-variable(ctx, var-name)
  if is-empty(val) {
    ([], "no-var", (), false)
  } else {
    let ends = if type(val) == str { val.ends-with(".") } else { false }
    let final-attrs = if type(val) == str {
      (..attrs, "_ends-with-period": ends)
    } else { attrs }
    (finalize(val, final-attrs), "var", (), ends)
  }
}

#let format-number-ordinal-compiled(ctx, attrs) = {
  let var-name = attrs.at("variable", default: "")
  let val = get-variable(ctx, var-name)
  if is-empty(val) {
    ([], "no-var", (), false)
  } else {
    let num = safe-int(val)
    let result = if num != none {
      str(num) + get-ordinal-suffix(num, ctx)
    } else { val }
    let ends = if type(result) == str { result.ends-with(".") } else { false }
    let final-attrs = if type(result) == str {
      (..attrs, "_ends-with-period": ends)
    } else { attrs }
    (finalize(result, final-attrs), "var", (), ends)
  }
}

#let format-number-long-ordinal-compiled(ctx, attrs) = {
  let var-name = attrs.at("variable", default: "")
  let val = get-variable(ctx, var-name)
  if is-empty(val) {
    ([], "no-var", (), false)
  } else {
    let num = safe-int(val)
    let result = if num != none and num >= 1 and num <= 10 {
      let long-ordinal = lookup-term(
        ctx,
        "long-ordinal-" + zero-pad(num, 2),
        form: "long",
        plural: false,
      )
      if (
        long-ordinal == none
          or long-ordinal == ""
          or long-ordinal.starts-with("long-ordinal-")
      ) {
        str(num) + get-ordinal-suffix(num, ctx)
      } else {
        long-ordinal
      }
    } else if num != none {
      str(num) + get-ordinal-suffix(num, ctx)
    } else { val }
    let ends = if type(result) == str { result.ends-with(".") } else { false }
    let final-attrs = if type(result) == str {
      (..attrs, "_ends-with-period": ends)
    } else { attrs }
    (finalize(result, final-attrs), "var", (), ends)
  }
}

#let format-number-roman-compiled(ctx, attrs) = {
  let var-name = attrs.at("variable", default: "")
  let val = get-variable(ctx, var-name)
  if is-empty(val) {
    ([], "no-var", (), false)
  } else {
    let num = safe-int(val)
    let result = if num != none and num > 0 {
      numbering("i", num)
    } else { val }
    let ends = if type(result) == str { result.ends-with(".") } else { false }
    let final-attrs = if type(result) == str {
      (..attrs, "_ends-with-period": ends)
    } else { attrs }
    (finalize(result, final-attrs), "var", (), ends)
  }
}

// Fallback: keep interpreter-based path for unknown forms
#let format-number-compiled(ctx, attrs) = {
  let node = (tag: "number", attrs: attrs, children: ())
  let stub-interpret(children, c) = []
  let content = _handle-number(node, ctx, stub-interpret)
  let var-state = if is-empty(content) { "no-var" } else { "var" }
  let ends = if type(content) == str { content.ends-with(".") } else { false }
  (content, var-state, (), ends)
}

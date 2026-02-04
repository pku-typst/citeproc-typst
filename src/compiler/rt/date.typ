// citrus - Compiler Runtime: Date

#import "../../interpreter/date.typ": handle-date as _handle-date
#import "../../core/mod.typ": is-empty

/// Format date from a CSL <date> element
/// This is the hybrid adapter that calls the full interpreter implementation.
#let format-date-compiled(ctx, attrs, children) = {
  let node = (
    tag: "date",
    attrs: attrs,
    children: children,
  )

  let content = _handle-date(node, ctx)
  let var-state = if is-empty(content) { "no-var" } else { "var" }
  (content, var-state, ())
}

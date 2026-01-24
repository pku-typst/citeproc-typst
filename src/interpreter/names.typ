// citeproc-typst - Names Handler
//
// Handles <names> CSL element.

#import "../core/mod.typ": finalize, is-empty
#import "../text/names.typ": format-names, format-names-with-institutions
#import "../parsing/locales.typ": lookup-term

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

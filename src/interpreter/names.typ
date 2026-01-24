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
    // Check for subsequent-author-substitute (bibliography grouping)
    // CSL spec: "Substitution is limited to the names of the first cs:names element rendered"
    //
    // IMPLEMENTATION NOTE:
    // We identify the "first cs:names" by matching variable names from the structurally
    // first cs:names node in the bibliography layout (stored in ctx.substitute-vars).
    //
    // KNOWN LIMITATION:
    // If a layout contains multiple cs:names elements with the SAME variable attribute
    // (e.g., two separate `<names variable="author">` elements), this implementation
    // will substitute ALL of them, not just the first. However, this edge case is
    // extremely rare in real CSL styles - typically each variable appears in only one
    // cs:names element per layout.
    //
    // A fully spec-compliant fix would require mutable state to track "have we already
    // rendered the first cs:names?", which Typst's functional model doesn't support
    // without restructuring to two-pass rendering.
    let author-substitute = ctx.at("author-substitute", default: none)
    let substitute-vars = ctx.at("substitute-vars", default: "author")

    // Check if current variable matches the first cs:names element's variables
    let target-vars = substitute-vars.split(" ")
    let is-target-element = target-vars.contains(used-var)

    if author-substitute != none and is-target-element {
      // Return the substitute string instead of rendering names
      // CSL spec: "replaces the entire name list (including punctuation and terms
      // like 'et al' and 'and'), except for the affixes set on the cs:names element"
      let substitute-rule = ctx.at(
        "author-substitute-rule",
        default: "complete-all",
      )

      // IMPLEMENTATION NOTE:
      // "complete-each" and "partial-*" rules require per-name substitution and
      // partial matching between consecutive entries. Current implementation treats
      // them equivalently to "complete-all" (substitute entire name list when all
      // names match). This covers the most common use case (em-dash substitution).
      let result = if substitute-rule == "complete-each" {
        author-substitute
      } else {
        // "complete-all" (default): replace entire name list
        author-substitute
      }

      return finalize(result, attrs)
    }

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

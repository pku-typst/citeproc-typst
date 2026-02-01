// citrus - Names Handler
//
// Handles <names> CSL element.

#import "../core/mod.typ": finalize, is-empty
#import "../text/names.typ": format-names, format-names-with-institutions
#import "../parsing/mod.typ": lookup-term

// =============================================================================
// Helper Functions
// =============================================================================

/// Compare two name arrays for equality
///
/// CSL spec: When variable="editor translator" and both have identical names,
/// use the "editortranslator" term for the label instead of separate terms.
///
/// - names1: First array of name dicts
/// - names2: Second array of name dicts
/// Returns: bool - true if all names match
#let names-are-equal(names1, names2) = {
  if names1.len() != names2.len() { return false }
  if names1.len() == 0 { return false }

  for (i, name1) in names1.enumerate() {
    let name2 = names2.at(i)
    // Compare key name parts: family, given, prefix (dropping-particle), suffix
    let parts = ("family", "given", "prefix", "suffix")
    for part in parts {
      let v1 = name1.at(part, default: "")
      let v2 = name2.at(part, default: "")
      if v1 != v2 { return false }
    }
  }
  true
}

/// Get the common term for merged name variables
///
/// CSL spec: When multiple variables like "editor translator" have identical names,
/// use a combined term (e.g., "editortranslator") for the label.
///
/// - var-names: Array of variable names (e.g., ("editor", "translator"))
/// - ctx: Context with parsed names
/// Returns: (common-term: str or none, names: array) - the merged term name and the names to render
#let get-common-term-for-variables(var-names, ctx) = {
  // Only applicable for exactly 2 variables
  if var-names.len() != 2 {
    return (common-term: none, names: none, used-var: none)
  }

  let var1 = var-names.at(0)
  let var2 = var-names.at(1)
  let names1 = ctx.parsed-names.at(var1, default: ())
  let names2 = ctx.parsed-names.at(var2, default: ())

  // Both must have names
  if names1.len() == 0 or names2.len() == 0 {
    return (common-term: none, names: none, used-var: none)
  }

  // Check if names are identical
  if not names-are-equal(names1, names2) {
    return (common-term: none, names: none, used-var: none)
  }

  // Build combined term name (variables sorted and joined)
  // e.g., ("editor", "translator") -> "editortranslator"
  let sorted-vars = var-names.sorted()
  let common-term = sorted-vars.join("")

  // Check if the locale has this term
  let term-value = lookup-term(ctx, common-term, form: "short", plural: false)
  if term-value == "" {
    // Also try long form
    term-value = lookup-term(ctx, common-term, form: "long", plural: false)
  }

  if term-value == "" {
    return (common-term: none, names: none, used-var: none)
  }

  // Return the first variable's names (they're identical) and the common term
  (common-term: common-term, names: names1, used-var: var1)
}

/// Handle <names> element
/// Uses stack-based interpreter internally for substitute processing
/// The third parameter is ignored (kept for dispatch table compatibility)
#let handle-names(node, ctx, .._rest) = {
  // Support suppress-author for collapse (CSL spec: subsequent cites in collapsed group omit author)
  let var-names-str = node
    .at("attrs", default: (:))
    .at("variable", default: "author")
  if (
    ctx.at("suppress-author", default: false)
      and var-names-str.contains("author")
  ) {
    return []
  }

  // Import here to avoid circular dependency at module level
  import "stack.typ": interpret-children-stack
  let attrs = node.at("attrs", default: (:))
  let children = node.at("children", default: ())
  let var-names = attrs.at("variable", default: "author").split(" ")

  // Check for merged editor-translator pattern first
  // CSL spec: When variable="editor translator" and both have identical names,
  // render once with "editortranslator" label
  let common-term-result = get-common-term-for-variables(var-names, ctx)
  let common-term = common-term-result.common-term
  let names = common-term-result.names
  let used-var = common-term-result.used-var

  // Check for form="count" - special handling for multiple variables
  // CSL spec: form="count" returns the total count of names across all variables
  let name-node = children.find(c => (
    type(c) == dictionary and c.at("tag", default: "") == "name"
  ))
  let name-attrs = if name-node != none {
    name-node.at("attrs", default: (:))
  } else { (:) }
  let name-form = name-attrs.at("form", default: "long")

  if name-form == "count" {
    // For form="count", sum the counts from ALL variables (after et-al truncation each)
    import "../text/names.typ": _resolve-et-al-settings
    let total-count = 0
    for var-name in var-names {
      let var-names-list = ctx.parsed-names.at(var-name, default: ())
      if var-names-list.len() > 0 {
        // Apply et-al truncation per CSL spec
        let et-al = _resolve-et-al-settings(name-attrs, ctx)
        let use-et-al = (
          var-names-list.len() >= et-al.et-al-min
            and et-al.et-al-use-first < var-names-list.len()
        )
        let show-count = if use-et-al { et-al.et-al-use-first } else {
          var-names-list.len()
        }
        total-count += show-count
      }
    }
    if total-count > 0 {
      return finalize(str(total-count), attrs)
    }
    // Fall through to substitute handling if no names found
  }

  // If no common term match, try each variable in order (standard behavior)
  if names == none {
    for var-name in var-names {
      let candidate = ctx.parsed-names.at(var-name, default: ())
      if candidate.len() > 0 {
        names = candidate
        used-var = var-name
        break
      }
    }
  }

  if names == none or names.len() == 0 {
    // Try substitute - CSL spec: try each child in order, use FIRST that produces output
    let substitute = children.find(c => (
      type(c) == dictionary and c.at("tag", default: "") == "substitute"
    ))
    if substitute != none {
      // CSL spec: "cs:names elements in cs:substitute inherit any name and label
      // elements from the parent cs:names element."
      // Extract parent's name and label elements for inheritance
      let parent-name-node = children.find(c => (
        type(c) == dictionary and c.at("tag", default: "") == "name"
      ))
      let parent-label-node = children.find(c => (
        type(c) == dictionary and c.at("tag", default: "") == "label"
      ))

      let sub-result = []
      for sub-child in substitute.at("children", default: ()) {
        // For names elements, inject parent's name/label if not present
        let child-to-render = if (
          type(sub-child) == dictionary
            and sub-child.at("tag", default: "") == "names"
        ) {
          let sub-children = sub-child.at("children", default: ())
          let has-name = sub-children.any(c => (
            type(c) == dictionary and c.at("tag", default: "") == "name"
          ))
          let has-label = sub-children.any(c => (
            type(c) == dictionary and c.at("tag", default: "") == "label"
          ))

          // Build new children list with inherited elements
          let new-children = sub-children
          if not has-name and parent-name-node != none {
            new-children = (parent-name-node,) + new-children
          }
          if not has-label and parent-label-node != none {
            new-children = new-children + (parent-label-node,)
          }

          // Create modified node with inherited children
          let modified = sub-child
          modified.insert("children", new-children)
          modified
        } else {
          sub-child
        }

        let rendered = interpret-children-stack((child-to-render,), ctx)
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

    // Determine substitution parameters for format-names
    // These will be passed to format-names to handle inline substitution
    let substitute-string-to-use = none
    let substitute-count-to-use = 0

    if author-substitute != none and is-target-element {
      // CSL spec: "replaces the entire name list (including punctuation and terms
      // like 'et al' and 'and'), except for the affixes set on the cs:names element"
      let substitute-rule = ctx.at(
        "author-substitute-rule",
        default: "complete-all",
      )
      let substitute-count = ctx.at("author-substitute-count", default: 0)

      if substitute-rule == "complete-all" {
        // Replace entire name list with substitute string (no inline substitution)
        return finalize(author-substitute, attrs)
      } else if substitute-rule == "complete-each" {
        // All names match: substitute each name inline
        substitute-string-to-use = author-substitute
        substitute-count-to-use = substitute-count
      } else if substitute-rule == "partial-each" {
        // Substitute matching names from start inline
        substitute-string-to-use = author-substitute
        substitute-count-to-use = substitute-count
      } else if substitute-rule == "partial-first" {
        // Substitute only first name inline
        if substitute-count > 0 {
          substitute-string-to-use = author-substitute
          substitute-count-to-use = 1
        }
      }
    }

    // Find name formatting options
    let name-node = children.find(c => (
      type(c) == dictionary and c.at("tag", default: "") == "name"
    ))
    let name-attrs = if name-node != none {
      name-node.at("attrs", default: (:))
    } else { (:) }

    // Parse <name-part> children from <name> element
    // CSL spec: <name-part name="family"> and <name-part name="given"> control formatting
    let name-parts = (:)
    if name-node != none {
      let name-children = name-node.at("children", default: ())
      for child in name-children {
        if (
          type(child) == dictionary
            and child.at("tag", default: "") == "name-part"
        ) {
          let part-attrs = child.at("attrs", default: (:))
          let part-name = part-attrs.at("name", default: "")
          if part-name in ("family", "given") {
            name-parts.insert(part-name, part-attrs)
          }
        }
      }
    }

    // Find institution formatting options (CSL-M extension)
    let institution-node = children.find(c => (
      type(c) == dictionary and c.at("tag", default: "") == "institution"
    ))
    let institution-attrs = if institution-node != none {
      institution-node.at("attrs", default: (:))
    } else { none }

    // Find et-al element if present (CSL spec: can override term with term="...")
    // Also extract formatting attributes (font-style, font-weight, etc.)
    let et-al-node = children.find(c => (
      type(c) == dictionary and c.at("tag", default: "") == "et-al"
    ))
    let et-al-attrs = if et-al-node != none {
      et-al-node.at("attrs", default: (:))
    } else { (:) }
    let et-al-term = et-al-attrs.at("term", default: "et-al")

    // Find label if present
    let label-node = children.find(c => (
      type(c) == dictionary and c.at("tag", default: "") == "label"
    ))
    let label-content = if label-node != none {
      let label-attrs = label-node.at("attrs", default: (:))
      let form = label-attrs.at("form", default: "long")
      let plural = names.len() > 1
      // Use common term (e.g., "editortranslator") if available, otherwise use variable name
      let term-name = if common-term != none { common-term } else { used-var }
      let term = lookup-term(ctx, term-name, form: form, plural: plural)
      // Only apply formatting if term is non-empty (to avoid prefix/suffix on empty content)
      if term == "" { [] } else { finalize(term, label-attrs) }
    } else { [] }

    // Format names (with institution support if cs:institution is present)
    // Pass substitute parameters for inline substitution
    let names-content = if institution-attrs != none {
      format-names-with-institutions(
        names,
        name-attrs,
        institution-attrs,
        ctx,
        name-parts: name-parts,
        substitute-string: substitute-string-to-use,
        substitute-count: substitute-count-to-use,
        et-al-term: et-al-term,
        et-al-attrs: et-al-attrs,
      )
    } else {
      format-names(
        names,
        name-attrs,
        ctx,
        name-parts: name-parts,
        substitute-string: substitute-string-to-use,
        substitute-count: substitute-count-to-use,
        et-al-term: et-al-term,
        et-al-attrs: et-al-attrs,
      )
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

      // If label has its own prefix, use it directly; otherwise use names delimiter
      let label-attrs = if label-node != none {
        label-node.at("attrs", default: (:))
      } else { (:) }
      let label-has-prefix = label-attrs.at("prefix", default: "") != ""

      if label-position == "before" {
        [#label-content #names-content]
      } else if label-has-prefix {
        // Label has prefix - no extra delimiter needed
        [#names-content#label-content]
      } else {
        // No prefix on label - use names delimiter
        [#names-content#attrs.at("delimiter", default: ", ")#label-content]
      }
    } else { names-content }

    finalize(result, attrs)
  }
}

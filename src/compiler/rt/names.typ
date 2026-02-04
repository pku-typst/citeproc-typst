// citrus - Compiler Runtime: Names

#import "../../interpreter/names.typ": handle-names as _handle-names
#import "../../core/mod.typ": finalize, is-empty
#import "../../parsing/mod.typ": lookup-term
#import "../../interpreter/stack.typ": interpret-children-stack
#import "../../text/names.typ": (
  _resolve-name-attr, apply-name-formatting, format-names,
  format-names-with-institutions,
)

/// Compare two name arrays for equality
#let names-are-equal(names1, names2) = {
  if names1.len() != names2.len() { return false }
  if names1.len() == 0 { return false }

  for (i, name1) in names1.enumerate() {
    let name2 = names2.at(i)
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
#let get-common-term-for-variables(var-names, ctx) = {
  if var-names.len() != 2 {
    return (common-term: none, names: none, used-var: none)
  }

  let var1 = var-names.at(0)
  let var2 = var-names.at(1)
  let names1 = ctx.parsed-names.at(var1, default: ())
  let names2 = ctx.parsed-names.at(var2, default: ())

  if names1.len() == 0 or names2.len() == 0 {
    return (common-term: none, names: none, used-var: none)
  }

  if not names-are-equal(names1, names2) {
    return (common-term: none, names: none, used-var: none)
  }

  let sorted-vars = var-names.sorted()
  let common-term = sorted-vars.join("")

  let term-value = lookup-term(ctx, common-term, form: "long", plural: false)
  if term-value == none or term-value == "" {
    return (common-term: none, names: none, used-var: none)
  }

  (common-term: common-term, names: names1, used-var: var1)
}

/// Render a single variable name list using a precomputed plan.
#let _render-names-plan(
  ctx,
  attrs,
  plan,
  var-name,
  names,
  term-override: none,
) = {
  // Subsequent-author-substitute handling (inline substitution only)
  let substitute-string-to-use = none
  let substitute-count-to-use = 0
  let author-substitute = ctx.at("author-substitute", default: none)
  if author-substitute != none {
    let substitute-vars = ctx.at("substitute-vars", default: "author")
    let target-vars = substitute-vars.split(" ")
    let is-target-element = target-vars.contains(var-name)
    if is-target-element {
      let substitute-rule = ctx.at(
        "author-substitute-rule",
        default: "complete-all",
      )
      let substitute-count = ctx.at("author-substitute-count", default: 0)
      if substitute-rule == "complete-all" {
        let content = finalize(author-substitute, attrs)
        let var-state = if is-empty(content) { "no-var" } else { "var" }
        return (content, var-state)
      } else if substitute-rule == "complete-each" {
        substitute-string-to-use = author-substitute
        substitute-count-to-use = substitute-count
      } else if substitute-rule == "partial-each" {
        substitute-string-to-use = author-substitute
        substitute-count-to-use = substitute-count
      } else if substitute-rule == "partial-first" {
        if substitute-count > 0 {
          substitute-string-to-use = author-substitute
          substitute-count-to-use = 1
        }
      }
    }
  }

  let name-attrs = plan.at("name-attrs", default: (:))
  let name-parts = plan.at("name-parts", default: (:))
  let et-al-attrs = plan.at("et-al-attrs", default: (:))
  let et-al-term = plan.at("et-al-term", default: "et-al")
  let institution-attrs = plan.at("institution-attrs", default: none)

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

  // Apply name-level formatting and affixes
  names-content = apply-name-formatting(names-content, name-attrs)
  let name-prefix = name-attrs.at("prefix", default: "")
  let name-suffix = name-attrs.at("suffix", default: "")
  if (
    (name-prefix != "" or name-suffix != "") and not is-empty(names-content)
  ) {
    names-content = [#name-prefix#names-content#name-suffix]
  }

  // Optional label
  let result = names-content
  if plan.at("has-label", default: false) {
    let label-attrs = plan.at("label-attrs", default: (:))
    let form = label-attrs.at("form", default: "long")
    let plural = names.len() > 1
    let term-name = if term-override != none { term-override } else { var-name }
    let term = lookup-term(ctx, term-name, form: form, plural: plural)
    let label-content = if term == none or term == "" {
      []
    } else {
      finalize(term, label-attrs)
    }

    if label-content != [] {
      let label-position = plan.at("label-position", default: "after")
      result = if label-position == "before" {
        [#label-content #names-content]
      } else {
        [#names-content#label-content]
      }
    }
  }

  let content = finalize(result, attrs)
  let var-state = if is-empty(content) { "no-var" } else { "var" }
  (content, var-state)
}

/// Format names from a CSL <names> element
/// This is the hybrid adapter that calls the full interpreter implementation.
///
/// - ctx: Context dictionary with parsed-names, fields, locale, etc.
/// - attrs: Dictionary of CSL attributes (variable, form, delimiter, etc.)
/// - children: Array of child nodes (name, label, et-al, substitute, etc.)
/// Returns: (content, var-state, done-vars) tuple
#let format-names-compiled(ctx, attrs, children) = {
  // Build a node structure that the interpreter expects
  let node = (
    tag: "names",
    attrs: attrs,
    children: children,
  )

  // Call the interpreter's handle-names
  let (content, done-vars) = _handle-names(node, ctx)

  // Determine var-state based on output
  let var-state = if is-empty(content) {
    // Check if any variable was expected
    let var-names = attrs.at("variable", default: "author").split(" ")
    let has-any = var-names.any(v => (
      ctx.at("parsed-names", default: (:)).at(v, default: ()).len() > 0
    ))
    if has-any { "var" } else { "no-var" }
  } else {
    "var"
  }

  (content, var-state, done-vars)
}

/// Fast path for <names> with a single variable and no <substitute>.
/// Expects a precomputed plan from the compiler to avoid child scans.
#let format-names-single-compiled(ctx, attrs, plan) = {
  let var-name = plan.at("var", default: "author")

  // Respect suppress-author for collapse
  if ctx.at("suppress-author", default: false) and var-name == "author" {
    let names = ctx.at("parsed-names", default: (:)).at(var-name, default: ())
    let var-state = if names.len() > 0 { "var" } else { "no-var" }
    return ([], var-state, ())
  }

  let names = ctx.at("parsed-names", default: (:)).at(var-name, default: ())
  if names.len() == 0 {
    return ([], "no-var", ())
  }

  let (content, var-state) = _render-names-plan(
    ctx,
    attrs,
    plan,
    var-name,
    names,
  )
  (content, var-state, ())
}

/// Fast path for <names> with multiple variables and no <substitute>.
#let format-names-multi-compiled(ctx, attrs, plan) = {
  let var-names = plan.at("vars", default: ())
  if var-names.len() == 0 {
    return ([], "no-var", ())
  }

  // Check for merged editor-translator pattern
  let common-term-result = get-common-term-for-variables(var-names, ctx)
  let common-term = common-term-result.common-term
  let names = common-term-result.names
  let used-var = common-term-result.used-var

  if names != none and used-var != none {
    let (content, var-state) = _render-names-plan(
      ctx,
      attrs,
      plan,
      used-var,
      names,
      term-override: common-term,
    )
    return (content, var-state, ())
  }

  // Collect all non-empty variables
  let vars-with-names = ()
  for var-name in var-names {
    let candidate = ctx.parsed-names.at(var-name, default: ())
    if candidate.len() > 0 {
      vars-with-names.push((var: var-name, names: candidate))
    }
  }

  if vars-with-names.len() == 0 {
    return ([], "no-var", ())
  }

  if vars-with-names.len() == 1 {
    let single = vars-with-names.first()
    let (content, var-state) = _render-names-plan(
      ctx,
      attrs,
      plan,
      single.var,
      single.names,
    )
    return (content, var-state, ())
  }

  let names-delimiter = plan.at("names-delimiter", default: none)
  if names-delimiter == none {
    names-delimiter = _resolve-name-attr("names-delimiter", (:), ctx)
  }
  if names-delimiter == none { names-delimiter = ", " }

  let rendered-parts = ()
  for var-info in vars-with-names {
    let (part, _state) = _render-names-plan(
      ctx,
      attrs,
      plan,
      var-info.var,
      var-info.names,
    )
    if not is-empty(part) {
      rendered-parts.push(part)
    }
  }

  if rendered-parts.len() == 0 {
    ([], "no-var", ())
  } else {
    (rendered-parts.join(names-delimiter), "var", ())
  }
}

/// Fast path for <names> with <substitute> handling.
#let format-names-substitute-compiled(ctx, attrs, plan) = {
  let var-names = plan.at("vars", default: ())
  if var-names.len() == 0 {
    return ([], "no-var", ())
  }

  let (content, var-state, _done) = if var-names.len() == 1 {
    format-names-single-compiled(ctx, attrs, plan)
  } else {
    format-names-multi-compiled(ctx, attrs, plan)
  }

  if var-state == "var" {
    return (content, var-state, ())
  }

  let author-substitute = ctx.at("author-substitute", default: none)
  let substitute-vars = ctx.at("substitute-vars", default: "author")
  let target-vars = substitute-vars.split(" ")
  let is-target-element = var-names.any(v => target-vars.contains(v))

  if author-substitute != none and is-target-element {
    let substitute-rule = ctx.at(
      "author-substitute-rule",
      default: "complete-all",
    )
    let substitute-count = ctx.at("author-substitute-count", default: 0)
    if substitute-rule == "complete-all" {
      return (finalize(author-substitute, attrs), "var", ())
    } else if substitute-rule == "partial-each" and substitute-count > 0 {
      return (finalize(author-substitute, attrs), "var", ())
    } else if substitute-rule == "complete-each" {
      if substitute-count > 0 {
        return (finalize(author-substitute, attrs), "var", ())
      }
    }
  }

  let substitute-children = plan.at("substitute-children", default: ())
  if substitute-children.len() == 0 {
    return ([], "no-var", ())
  }

  let parent-name-node = plan.at("parent-name-node", default: none)
  let parent-label-node = plan.at("parent-label-node", default: none)

  let sub-result = []
  let sub-done-vars = ()
  for sub-child in substitute-children {
    let child-var = if type(sub-child) == dictionary {
      let child-tag = sub-child.at("tag", default: "")
      let child-attrs = sub-child.at("attrs", default: (:))
      if child-tag == "text" and "variable" in child-attrs {
        (child-attrs.variable,)
      } else if child-tag == "names" and "variable" in child-attrs {
        child-attrs.variable.split(" ")
      } else {
        ()
      }
    } else {
      ()
    }

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

      let new-children = sub-children
      if not has-name and parent-name-node != none {
        new-children = (parent-name-node,) + new-children
      }
      if not has-label and parent-label-node != none {
        new-children = new-children + (parent-label-node,)
      }

      let modified = sub-child
      modified.insert("children", new-children)
      modified
    } else {
      sub-child
    }

    let is-term-element = (
      type(sub-child) == dictionary
        and sub-child.at("tag", default: "") == "text"
        and "term" in sub-child.at("attrs", default: (:))
    )

    if is-term-element {
      let term-name = sub-child
        .at("attrs", default: (:))
        .at("term", default: "")
      let form = sub-child.at("attrs", default: (:)).at("form", default: "long")
      let term-value = lookup-term(
        ctx,
        term-name,
        form: form,
        plural: false,
      )
      if term-value != none {
        let rendered = interpret-children-stack((child-to-render,), ctx)
        sub-result = rendered
        sub-done-vars = child-var
        break
      }
    } else {
      let rendered = interpret-children-stack((child-to-render,), ctx)
      if not is-empty(rendered) {
        sub-result = rendered
        sub-done-vars = child-var
        break
      }
    }
  }

  let content = finalize(sub-result, attrs)
  let var-state = if is-empty(content) { "no-var" } else { "var" }
  (content, var-state, sub-done-vars)
}

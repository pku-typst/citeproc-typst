// citrus - Stack-based Interpreter with Memoization
//
// This is the PRODUCTION interpreter for CSL AST interpretation.
// Uses an explicit stack instead of recursion to enable mutable macro cache.
// This reduces O(calls * depth) to O(unique macros) for macro expansion.
//
// Results are stored as (content, var-state, done-vars) tuples:
// - content: The rendered content
// - var-state: One of "var", "no-var", or "none" (for group suppression)
// - done-vars: Array of variable names that were rendered (for substitute quashing)
//
// var-state values:
//   - "var": Has variable output (variables were referenced and produced content)
//   - "no-var": Referenced variables but all were empty
//   - "none": No variable references (only terms/values/conditions)
//
// CSL Group Suppression rule:
//   - If any child has "var" state: render group normally
//   - If all children have "no-var" state: suppress entire group
//   - If all children have "none" state: render group normally (no variables involved)
//
// CSL Substitute Quashing rule:
//   - Variables rendered through <substitute> are added to done-vars
//   - Subsequent references to those variables produce no output

#import "../core/mod.typ": apply-text-case, finalize, is-empty
#import "../data/conditions.typ": eval-condition
#import "../data/variables.typ": get-variable
#import "../parsing/mod.typ": lookup-term
#import "../text/ranges.typ": format-page-range
#import "../text/quotes.typ": apply-quotes, transform-quotes-at-level
#import "../text/names.typ": _resolve-et-al-settings, names-end-flag
#import "names.typ": handle-names
#import "date.typ": handle-date
#import "number.typ": handle-label, handle-number

/// Merge var-states from multiple children
/// Priority: "var" > "no-var" > "none"
#let merge-var-state(states) = {
  if states.any(s => s == "var") { "var" } else if states.any(s => (
    s == "no-var"
  )) { "no-var" } else { "none" }
}

/// Check if group should be suppressed based on var-states
///
/// CSL spec: "cs:group and its child elements are suppressed if
/// a) at least one rendering element in cs:group calls a variable, and
/// b) all variables that are called are empty."
///
/// This means: if group contains any variable call AND all variables are empty,
/// suppress the entire group INCLUDING terms/values.
#let should-suppress-group(states) = {
  let has-any-var = states.any(s => s == "var")
  let has-any-no-var = states.any(s => s == "no-var")

  // Condition a): at least one element calls a variable (either "var" or "no-var")
  let has-variable-call = has-any-var or has-any-no-var

  // If no variable calls at all, don't suppress (pure term/value group)
  if not has-variable-call { return false }

  // Condition b): all called variables are empty (no "var" state)
  // If any variable produced output, don't suppress
  if has-any-var { return false }

  // Both conditions met: has variable calls, but all are empty -> suppress
  true
}

/// Process a leaf node (text variable/value/term, number, label)
/// Returns: (content, var-state, done-vars)
#let process-leaf(node, ctx) = {
  let tag = node.at("tag", default: "")
  let attrs = node.at("attrs", default: (:))
  let done-vars = ctx.at("done-vars", default: ())

  if tag == "text" {
    if "variable" in attrs {
      let var-name = attrs.variable

      // CSL Substitute Quashing: skip if variable already rendered via substitute
      if var-name in done-vars {
        return ([], "none", (), false)
      }

      let form = attrs.at("form", default: "long")

      // CSL form="short": try variable-short first, fallback to variable
      let val = if form == "short" {
        let short-name = var-name + "-short"
        let short-val = get-variable(ctx, short-name)
        if short-val != "" { short-val } else { get-variable(ctx, var-name) }
      } else {
        get-variable(ctx, var-name)
      }

      if val != "" {
        let result = if (
          var-name == "page"
            or var-name == "page-first"
            or var-name == "locator"
        ) {
          let page-format = ctx.style.at("page-range-format", default: none)
          format-page-range(val, format: page-format, ctx: ctx)
        } else { val }

        // Apply text-case FIRST while content is still a string
        // CSL spec: text-case transformation happens before quotes are added
        // CSL spec: title case only applies to English content
        let cased = apply-text-case(result, attrs, ctx: ctx)

        // Normalize embedded quotes in content
        // CSL spec: quotes in field content should be normalized to proper level
        // - At level 0 (not inside quotes): single quotes -> double quotes
        // - At level 1 (inside outer quotes): double quotes -> single quotes
        let quote-level = ctx.at("quote-level", default: 0)
        let normalized = if type(cased) == str {
          // Always normalize quotes, even without quotes="true"
          // The target level depends on whether we're adding outer quotes
          let has-quotes = attrs.at("quotes", default: "false") == "true"
          if has-quotes {
            // Will add outer quotes, so embedded quotes go to level+1
            transform-quotes-at-level(cased, ctx, quote-level + 1)
          } else {
            // No outer quotes, normalize to current level
            transform-quotes-at-level(cased, ctx, quote-level)
          }
        } else { cased }

        // Apply quotes if requested (after normalization)
        let quoted = if attrs.at("quotes", default: "false") == "true" {
          apply-quotes(normalized, ctx, level: quote-level)
        } else { normalized }

        let final-attrs = if type(quoted) == str {
          (..attrs, "_ends-with-period": quoted.ends-with("."))
        } else { attrs }
        let ends = if type(quoted) == str { quoted.ends-with(".") } else {
          false
        }
        (finalize(quoted, final-attrs), "var", (), ends) // Variable has output
      } else {
        ([], "no-var", (), false) // Variable referenced but empty
      }
    } else if "value" in attrs {
      let result = attrs.value
      let quote-level = ctx.at("quote-level", default: 0)

      // Normalize embedded quotes in value (same as variables)
      let has-quotes = attrs.at("quotes", default: "false") == "true"
      let normalized = if type(result) == str and not is-empty(result) {
        if has-quotes {
          transform-quotes-at-level(result, ctx, quote-level + 1)
        } else {
          transform-quotes-at-level(result, ctx, quote-level)
        }
      } else { result }

      let quoted = if has-quotes and not is-empty(normalized) {
        apply-quotes(normalized, ctx, level: quote-level)
      } else { normalized }
      let final-attrs = if type(quoted) == str {
        (..attrs, "_ends-with-period": quoted.ends-with("."))
      } else { attrs }
      let ends = if type(quoted) == str { quoted.ends-with(".") } else { false }
      (finalize(quoted, final-attrs), "none", (), ends) // Literal value, no variable reference
    } else if "term" in attrs {
      let form = attrs.at("form", default: "long")
      let plural = attrs.at("plural", default: "false") == "true"
      let result = lookup-term(ctx, attrs.term, form: form, plural: plural)
      // Term can be none (undefined) or "" (defined as empty)
      // Both render as empty, but the distinction matters for substitute logic
      let term-str = if result != none { result } else { "" }
      let final-attrs = if type(term-str) == str {
        (..attrs, "_ends-with-period": term-str.ends-with("."))
      } else { attrs }
      let ends = term-str.ends-with(".")
      (finalize(term-str, final-attrs), "none", (), ends) // Term, no variable reference
    } else {
      ([], "none", (), false)
    }
  } else if tag == "number" {
    let result = handle-number(node, ctx, n => [])
    if is-empty(result) {
      ([], "no-var", (), false) // Number variable referenced but empty
    } else {
      let ends = if type(result) == str { result.ends-with(".") } else { false }
      (result, "var", (), ends) // Number variable has output
    }
  } else if tag == "label" {
    let result = handle-label(node, ctx, n => [])
    let ends = if type(result) == str { result.ends-with(".") } else { false }
    (result, "none", (), ends) // Label is a term, not a variable
  } else if tag == "names" {
    // handle-names now returns (content, done-vars) for substitute quashing
    let (result, names-done-vars) = handle-names(node, ctx)
    if is-empty(result) {
      ([], "no-var", names-done-vars, false)
    } else {
      let node-children = node.at("children", default: ())
      let name-node = node-children.find(c => (
        type(c) == dictionary and c.at("tag", default: "") == "name"
      ))
      let name-attrs = if name-node != none {
        name-node.at("attrs", default: (:))
      } else { (:) }

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

      let et-al-node = node-children.find(c => (
        type(c) == dictionary and c.at("tag", default: "") == "et-al"
      ))
      let et-al-attrs = if et-al-node != none {
        et-al-node.at("attrs", default: (:))
      } else { (:) }
      let et-al-term = et-al-attrs.at("term", default: "et-al")
      let et-al = _resolve-et-al-settings(name-attrs, ctx)

      let var-names = attrs.at("variable", default: "author").split(" ")
      let last-names = none
      for var-name in var-names {
        let candidate = ctx.parsed-names.at(var-name, default: ())
        if candidate.len() > 0 { last-names = candidate }
      }
      let ends = if last-names != none {
        names-end-flag(
          last-names,
          name-attrs,
          name-parts,
          ctx,
          et-al-term,
          et-al,
        )
      } else { false }

      (result, "var", names-done-vars, ends)
    }
  } else if tag == "date" {
    let result = handle-date(node, ctx)
    if is-empty(result) {
      ([], "no-var", (), false) // Date variable referenced but empty
    } else {
      let ends = if type(result) == str { result.ends-with(".") } else { false }
      (result, "var", (), ends) // Date variable has output
    }
  } else {
    ([], "none", (), false)
  }
}

/// Check if a node is a simple leaf (can be processed immediately)
#let is-leaf(node) = {
  if type(node) != dictionary { return true }
  let tag = node.at("tag", default: "")
  let attrs = node.at("attrs", default: (:))

  // Macro calls are not leaves
  if tag == "text" and "macro" in attrs { return false }
  // Groups and choose are not leaves
  if tag in ("group", "choose") { return false }
  // Everything else is a leaf
  true
}

/// Stack-based interpreter with memoization
/// - children: List of nodes to interpret
/// - ctx: Interpretation context
/// - delimiter: Optional delimiter for joining top-level results
/// Returns: Joined content from all children
#let interpret-children-stack(children, ctx, delimiter: none) = {
  if children.len() == 0 { return [] }

  // Work stack: (node, state, meta)
  // Result stack: stores results as (content, var-state, done-vars, ends-with-period) tuples
  // Macro cache (mutable within this function!)
  // Accumulated done-vars for substitute quashing (mutable)
  let macro-cache = (:)
  let results = ()
  let accumulated-done-vars = ctx.at("done-vars", default: ())

  // Initialize stack with children (reversed for correct order)
  let stack = children.rev().map(c => (node: c, state: "pending", meta: (:)))

  // Process stack
  while stack.len() > 0 {
    let item = stack.pop()
    let node = item.node
    let state = item.state
    let meta = item.meta

    // Handle string nodes
    if type(node) == str {
      let text = node.trim()
      results.push((text, "none", (), text.ends-with("."))) // String literal, no variable
      continue
    }

    // Handle non-dict nodes
    if type(node) != dictionary {
      results.push(([], "none", (), false))
      continue
    }

    let tag = node.at("tag", default: "")
    let attrs = node.at("attrs", default: (:))
    let node-children = node.at("children", default: ())

    if state == "pending" {
      // Check for macro call
      if tag == "text" and "macro" in attrs {
        let macro-name = attrs.macro

        // Check cache first!
        if macro-name in macro-cache {
          // Cache hit - use cached result with formatting
          let cached = macro-cache.at(macro-name)
          let cached-done-vars = cached.at(2, default: ())
          let cached-ends = cached.at(3, default: false)
          let quote-level = ctx.at("quote-level", default: 0)
          let has-quotes = attrs.at("quotes", default: "false") == "true"
          let macro-content = cached.at(0)
          let normalized = if type(macro-content) == str {
            // Apply text-case + quote normalization on string content
            let cased = apply-text-case(macro-content, attrs, ctx: ctx)
            if has-quotes {
              transform-quotes-at-level(cased, ctx, quote-level + 1)
            } else {
              transform-quotes-at-level(cased, ctx, quote-level)
            }
          } else { macro-content }
          let quoted = if has-quotes {
            apply-quotes(normalized, ctx, level: quote-level)
          } else { normalized }
          let ends = if type(quoted) == str { quoted.ends-with(".") } else {
            cached-ends
          }
          // Accumulate done-vars from cached macro
          accumulated-done-vars = accumulated-done-vars + cached-done-vars
          results.push((
            finalize(quoted, (..attrs, "_ends-with-period": ends)),
            cached.at(1),
            cached-done-vars,
            ends,
          ))
        } else {
          // Cache miss - need to compute
          let macro-def = ctx.macros.at(macro-name, default: none)
          if macro-def != none and macro-def.children.len() > 0 {
            // Push marker for when children complete
            stack.push((
              node: node,
              state: "macro-pending",
              meta: (
                macro-name: macro-name,
                child-count: macro-def.children.len(),
                attrs: attrs,
              ),
            ))
            // Push macro children (reversed)
            for c in macro-def.children.rev() {
              stack.push((node: c, state: "pending", meta: (:)))
            }
          } else {
            // Empty or missing macro
            macro-cache.insert(macro-name, ([], "none", (), false))
            results.push(([], "none", (), false))
          }
        }
      } else if tag == "group" {
        if node-children.len() > 0 {
          // Push marker for when children complete
          stack.push((
            node: node,
            state: "group-pending",
            meta: (child-count: node-children.len(), attrs: attrs),
          ))
          // Push children (reversed)
          for c in node-children.rev() {
            stack.push((node: c, state: "pending", meta: (:)))
          }
        } else {
          results.push(([], "none", (), false))
        }
      } else if tag == "choose" {
        // Choose: evaluate conditions and process matching branch
        let matched = false
        for branch in node-children {
          if type(branch) != dictionary { continue }
          let branch-tag = branch.at("tag", default: "")
          let branch-attrs = branch.at("attrs", default: (:))
          let branch-children = branch.at("children", default: ())

          let should-take = if branch-tag == "if" or branch-tag == "else-if" {
            eval-condition(branch-attrs, ctx)
          } else if branch-tag == "else" {
            true
          } else {
            false
          }

          if should-take {
            if branch-children.len() > 0 {
              stack.push((
                node: node,
                state: "choose-pending",
                meta: (child-count: branch-children.len()),
              ))
              for c in branch-children.rev() {
                stack.push((node: c, state: "pending", meta: (:)))
              }
            } else {
              results.push(([], "none", (), false))
            }
            matched = true
            break
          }
        }
        // If no branch matched, push empty result
        if not matched {
          results.push(([], "none", (), false))
        }
      } else {
        // Leaf node - process immediately
        // Pass current accumulated done-vars in context
        let leaf-ctx = (..ctx, done-vars: accumulated-done-vars)
        let leaf-result = process-leaf(node, leaf-ctx)
        // Accumulate any new done-vars from the leaf
        let new-done-vars = leaf-result.at(2, default: ())
        accumulated-done-vars = accumulated-done-vars + new-done-vars
        results.push(leaf-result)
      }
    } else if state == "macro-pending" {
      // Macro children completed - collect last N results
      // Macros act as implicit groups for suppression purposes.
      // This is not explicitly in CSL spec, but citeproc-js behavior and
      // test "group_SuppressTermInMacro" confirms macros should suppress
      // terms when all variable calls are empty.
      let child-count = meta.child-count
      let ordered = results.slice(-child-count)
      results = results.slice(0, results.len() - child-count)

      // Merge done-vars from all children
      let merged-done-vars = ordered.map(r => r.at(2, default: ())).flatten()

      // Accumulate done-vars for subsequent siblings in parent scope
      accumulated-done-vars = accumulated-done-vars + merged-done-vars

      // Check var-states - apply group suppression to macros
      let states = ordered.map(r => r.at(1, default: "none"))

      if should-suppress-group(states) {
        // Suppress: macro referenced variables but none produced output
        macro-cache.insert(meta.macro-name, (
          [],
          "no-var",
          merged-done-vars,
          false,
        ))
        results.push(([], "no-var", merged-done-vars, false))
      } else {
        // Render normally
        let merged-state = merge-var-state(states)
        let contents = ordered.map(r => r.at(0)).filter(x => not is-empty(x))
        let joined = contents.join()
        let end-flag = false
        for r in ordered.rev() {
          if not end-flag {
            let c = r.at(0)
            if not is-empty(c) { end-flag = r.at(3, default: false) }
          }
        }
        let quote-level = ctx.at("quote-level", default: 0)
        let has-quotes = meta.attrs.at("quotes", default: "false") == "true"
        let normalized = if type(joined) == str {
          let cased = apply-text-case(joined, meta.attrs, ctx: ctx)
          if has-quotes {
            transform-quotes-at-level(cased, ctx, quote-level + 1)
          } else {
            transform-quotes-at-level(cased, ctx, quote-level)
          }
        } else { joined }
        let quoted = if has-quotes {
          apply-quotes(normalized, ctx, level: quote-level)
        } else { normalized }
        let end-flag = if type(quoted) == str { quoted.ends-with(".") } else {
          end-flag
        }
        let final-attrs = (..meta.attrs, "_ends-with-period": end-flag)

        // Cache the raw result (content, var-state, done-vars) without formatting
        macro-cache.insert(meta.macro-name, (
          joined,
          merged-state,
          merged-done-vars,
          end-flag,
        ))

        // Apply formatting and push
        results.push((
          finalize(quoted, final-attrs),
          merged-state,
          merged-done-vars,
          end-flag,
        ))
      }
    } else if state == "group-pending" {
      // Group children completed - collect last N results
      let child-count = meta.child-count
      let ordered = results.slice(-child-count)
      results = results.slice(0, results.len() - child-count)

      // Merge done-vars from all children
      let merged-done-vars = ordered.map(r => r.at(2, default: ())).flatten()

      // Accumulate done-vars for subsequent siblings in parent scope
      accumulated-done-vars = accumulated-done-vars + merged-done-vars

      // Check var-states for group suppression
      let states = ordered.map(r => r.at(1, default: "none"))

      if should-suppress-group(states) {
        // Suppress: all children reference variables but none produced output
        results.push(([], "no-var", merged-done-vars, false))
      } else {
        // Render normally
        let merged-state = merge-var-state(states)
        let group-delimiter = meta.attrs.at("delimiter", default: "")
        let parts = ordered.map(r => r.at(0)).filter(x => not is-empty(x))
        let all-strings = parts.all(p => type(p) == str)
        let joined = if group-delimiter != "" and parts.len() > 1 {
          parts.join(group-delimiter)
        } else if all-strings {
          parts.join("")
        } else {
          parts.join()
        }

        // Apply prefix/suffix
        let prefix = meta.attrs.at("prefix", default: "")
        let suffix = meta.attrs.at("suffix", default: "")
        let end-flag = false
        for r in ordered.rev() {
          if not end-flag {
            let c = r.at(0)
            if not is-empty(c) { end-flag = r.at(3, default: false) }
          }
        }
        if suffix != "" and suffix.ends-with(".") { end-flag = true }
        if not is-empty(joined) {
          // CSL spec: "a non-empty nested cs:group is treated as a non-empty variable
          // for the purposes of determining suppression of the outer cs:group"
          // So a non-empty group should report "var" state even if it only contains terms/values
          let final-state = if merged-state == "none" { "var" } else {
            merged-state
          }
          results.push((
            [#prefix#joined#suffix],
            final-state,
            merged-done-vars,
            end-flag,
          ))
        } else {
          results.push(([], merged-state, merged-done-vars, false))
        }
      }
    } else if state == "choose-pending" {
      // Choose branch completed - collect last N results
      let child-count = meta.child-count
      let ordered = results.slice(-child-count)
      results = results.slice(0, results.len() - child-count)

      // Merge done-vars from all children
      let merged-done-vars = ordered.map(r => r.at(2, default: ())).flatten()

      // Accumulate done-vars for subsequent siblings in parent scope
      accumulated-done-vars = accumulated-done-vars + merged-done-vars

      // Merge var-states
      let states = ordered.map(r => r.at(1, default: "none"))
      let merged-state = merge-var-state(states)

      let contents = ordered.map(r => r.at(0)).filter(x => not is-empty(x))
      let joined = contents.join()
      let end-flag = false
      for r in ordered.rev() {
        if not end-flag {
          let c = r.at(0)
          if not is-empty(c) { end-flag = r.at(3, default: false) }
        }
      }
      results.push((joined, merged-state, merged-done-vars, end-flag))
    }
  }

  // Final result: join all top-level results with optional delimiter
  // Extract content from tuples
  let final-contents = results.map(r => r.at(0)).filter(x => not is-empty(x))
  if delimiter != none {
    final-contents.join(delimiter)
  } else {
    final-contents.join()
  }
}

/// Convenience function to interpret a single node with stack
#let interpret-node-stack(node, ctx) = {
  interpret-children-stack((node,), ctx)
}

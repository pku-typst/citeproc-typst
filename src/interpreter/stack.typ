// citrus - Stack-based Interpreter with Memoization
//
// This is the PRODUCTION interpreter for CSL AST interpretation.
// Uses an explicit stack instead of recursion to enable mutable macro cache.
// This reduces O(calls * depth) to O(unique macros) for macro expansion.
//
// Results are stored as (content, var-state) tuples to track variable output.
// var-state is one of:
//   - "var": Has variable output (variables were referenced and produced content)
//   - "no-var": Referenced variables but all were empty
//   - "none": No variable references (only terms/values/conditions)
//
// CSL Group Suppression rule:
//   - If any child has "var" state: render group normally
//   - If all children have "no-var" state: suppress entire group
//   - If all children have "none" state: render group normally (no variables involved)

#import "../core/mod.typ": finalize, is-empty
#import "../data/conditions.typ": eval-condition
#import "../data/variables.typ": get-variable
#import "../parsing/mod.typ": lookup-term
#import "../text/ranges.typ": format-page-range
#import "../text/quotes.typ": apply-quotes
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
/// Returns: (content, var-state)
#let process-leaf(node, ctx) = {
  let tag = node.at("tag", default: "")
  let attrs = node.at("attrs", default: (:))

  if tag == "text" {
    if "variable" in attrs {
      let var-name = attrs.variable
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

        // Apply quotes if requested
        let quoted = if attrs.at("quotes", default: "false") == "true" {
          apply-quotes(result, ctx, level: 0)
        } else { result }

        (finalize(quoted, attrs), "var") // Variable has output
      } else {
        ([], "no-var") // Variable referenced but empty
      }
    } else if "value" in attrs {
      let result = attrs.value
      let quoted = if (
        attrs.at("quotes", default: "false") == "true" and not is-empty(result)
      ) {
        apply-quotes(result, ctx, level: 0)
      } else { result }
      (finalize(quoted, attrs), "none") // Literal value, no variable reference
    } else if "term" in attrs {
      let form = attrs.at("form", default: "long")
      let plural = attrs.at("plural", default: "false") == "true"
      let result = lookup-term(ctx, attrs.term, form: form, plural: plural)
      (finalize(result, attrs), "none") // Term, no variable reference
    } else {
      ([], "none")
    }
  } else if tag == "number" {
    let result = handle-number(node, ctx, n => [])
    if is-empty(result) {
      ([], "no-var") // Number variable referenced but empty
    } else {
      (result, "var") // Number variable has output
    }
  } else if tag == "label" {
    let result = handle-label(node, ctx, n => [])
    (result, "none") // Label is a term, not a variable
  } else if tag == "names" {
    let result = handle-names(node, ctx)
    if is-empty(result) {
      ([], "no-var") // Names variable referenced but empty
    } else {
      (result, "var") // Names variable has output
    }
  } else if tag == "date" {
    let result = handle-date(node, ctx)
    if is-empty(result) {
      ([], "no-var") // Date variable referenced but empty
    } else {
      (result, "var") // Date variable has output
    }
  } else {
    ([], "none")
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
  // Result stack: stores results as (content, var-state) tuples
  // Macro cache (mutable within this function!)
  let macro-cache = (:)
  let results = ()

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
      results.push((node.trim(), "none")) // String literal, no variable
      continue
    }

    // Handle non-dict nodes
    if type(node) != dictionary {
      results.push(([], "none"))
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
          results.push((finalize(cached.at(0), attrs), cached.at(1)))
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
            macro-cache.insert(macro-name, ([], "none"))
            results.push(([], "none"))
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
          results.push(([], "none"))
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
              results.push(([], "none"))
            }
            matched = true
            break
          }
        }
        // If no branch matched, push empty result
        if not matched {
          results.push(([], "none"))
        }
      } else {
        // Leaf node - process immediately
        results.push(process-leaf(node, ctx))
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

      // Check var-states - apply group suppression to macros
      let states = ordered.map(r => r.at(1, default: "none"))

      if should-suppress-group(states) {
        // Suppress: macro referenced variables but none produced output
        macro-cache.insert(meta.macro-name, ([], "no-var"))
        results.push(([], "no-var"))
      } else {
        // Render normally
        let merged-state = merge-var-state(states)
        let contents = ordered.map(r => r.at(0)).filter(x => not is-empty(x))
        let joined = contents.join()

        // Cache the raw result (content, var-state) without formatting
        macro-cache.insert(meta.macro-name, (joined, merged-state))

        // Apply formatting and push
        results.push((finalize(joined, meta.attrs), merged-state))
      }
    } else if state == "group-pending" {
      // Group children completed - collect last N results
      let child-count = meta.child-count
      let ordered = results.slice(-child-count)
      results = results.slice(0, results.len() - child-count)

      // Check var-states for group suppression
      let states = ordered.map(r => r.at(1, default: "none"))

      if should-suppress-group(states) {
        // Suppress: all children reference variables but none produced output
        results.push(([], "no-var"))
      } else {
        // Render normally
        let merged-state = merge-var-state(states)
        let group-delimiter = meta.attrs.at("delimiter", default: "")
        let parts = ordered.map(r => r.at(0)).filter(x => not is-empty(x))
        let joined = if group-delimiter != "" and parts.len() > 1 {
          parts.join(group-delimiter)
        } else {
          parts.join()
        }

        // Apply prefix/suffix
        let prefix = meta.attrs.at("prefix", default: "")
        let suffix = meta.attrs.at("suffix", default: "")
        if not is-empty(joined) {
          results.push(([#prefix#joined#suffix], merged-state))
        } else {
          results.push(([], merged-state))
        }
      }
    } else if state == "choose-pending" {
      // Choose branch completed - collect last N results
      let child-count = meta.child-count
      let ordered = results.slice(-child-count)
      results = results.slice(0, results.len() - child-count)

      // Merge var-states
      let states = ordered.map(r => r.at(1, default: "none"))
      let merged-state = merge-var-state(states)

      let contents = ordered.map(r => r.at(0)).filter(x => not is-empty(x))
      let joined = contents.join()
      results.push((joined, merged-state))
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

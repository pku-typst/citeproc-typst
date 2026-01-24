// citeproc-typst - Stack-based Interpreter with Memoization
//
// Uses an explicit stack instead of recursion to enable mutable macro cache.
// This reduces O(calls * depth) to O(unique macros) for macro expansion.

#import "../core/mod.typ": finalize, is-empty
#import "../data/variables.typ": get-variable
#import "../parsing/locales.typ": lookup-term
#import "../text/ranges.typ": format-page-range
#import "../text/quotes.typ": apply-quotes
#import "mod.typ": interpret-node
#import "names.typ": handle-names
#import "date.typ": handle-date
#import "number.typ": handle-label, handle-number

/// Stack item states
/// - "pending": Node not yet processed
/// - "children-pending": Waiting for children to complete
/// - "macro-pending": Waiting for macro children to complete

/// Process a leaf node (text variable/value/term, number, label)
#let process-leaf(node, ctx) = {
  let tag = node.at("tag", default: "")
  let attrs = node.at("attrs", default: (:))

  if tag == "text" {
    let result = if "variable" in attrs {
      let var-name = attrs.variable
      let val = get-variable(ctx, var-name)
      if val != "" {
        if var-name == "page" or var-name == "page-first" {
          let page-format = ctx.style.at("page-range-format", default: none)
          format-page-range(val, format: page-format, ctx: ctx)
        } else { val }
      } else { [] }
    } else if "value" in attrs {
      attrs.value
    } else if "term" in attrs {
      let form = attrs.at("form", default: "long")
      let plural = attrs.at("plural", default: "false") == "true"
      lookup-term(ctx, attrs.term, form: form, plural: plural)
    } else { [] }

    // Apply quotes if requested
    let quoted = if attrs.at("quotes", default: "false") == "true" and not is-empty(result) {
      apply-quotes(result, ctx, level: 0)
    } else { result }

    finalize(quoted, attrs)
  } else if tag == "number" {
    handle-number(node, ctx, n => [])  // Simple fallback
  } else if tag == "label" {
    handle-label(node, ctx, n => [])
  } else if tag == "names" {
    // Names is complex, use existing handler with recursive interpret
    handle-names(node, ctx, interpret-node)
  } else if tag == "date" {
    // Date is complex, use existing handler with recursive interpret
    handle-date(node, ctx, interpret-node)
  } else {
    []
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
/// Returns: Joined content from all children
#let interpret-children-stack(children, ctx) = {
  if children.len() == 0 { return [] }

  // Work stack: (node, state, meta)
  let stack = ()
  // Result stack: stores results as they complete
  let results = ()
  // Macro cache (mutable within this function!)
  let macro-cache = (:)

  // Initialize stack with children (reversed for correct order)
  let i = children.len() - 1
  while i >= 0 {
    stack.push((node: children.at(i), state: "pending", meta: (:)))
    i -= 1
  }

  // Process stack
  while stack.len() > 0 {
    let item = stack.pop()
    let node = item.node
    let state = item.state
    let meta = item.meta

    // Handle string nodes
    if type(node) == str {
      results.push(node.trim())
      continue
    }

    // Handle non-dict nodes
    if type(node) != dictionary {
      results.push([])
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
          results.push(finalize(cached, attrs))
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
            let j = macro-def.children.len() - 1
            while j >= 0 {
              stack.push((
                node: macro-def.children.at(j),
                state: "pending",
                meta: (:),
              ))
              j -= 1
            }
          } else {
            // Empty or missing macro
            macro-cache.insert(macro-name, [])
            results.push([])
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
          let j = node-children.len() - 1
          while j >= 0 {
            stack.push((node: node-children.at(j), state: "pending", meta: (:)))
            j -= 1
          }
        } else {
          results.push([])
        }
      } else if tag == "choose" {
        // Choose needs to evaluate conditions - delegate to existing logic
        // For simplicity, process inline
        let branch-result = []
        for branch in node-children {
          if type(branch) != dictionary { continue }
          let branch-tag = branch.at("tag", default: "")
          let branch-attrs = branch.at("attrs", default: (:))
          let branch-children = branch.at("children", default: ())

          if branch-tag == "if" or branch-tag == "else-if" {
            // Import condition evaluation
            import "../data/conditions.typ": eval-condition
            if eval-condition(branch-attrs, ctx) {
              // Process this branch's children
              if branch-children.len() > 0 {
                stack.push((
                  node: node,
                  state: "choose-pending",
                  meta: (child-count: branch-children.len()),
                ))
                let j = branch-children.len() - 1
                while j >= 0 {
                  stack.push((
                    node: branch-children.at(j),
                    state: "pending",
                    meta: (:),
                  ))
                  j -= 1
                }
              } else {
                results.push([])
              }
              break
            }
          } else if branch-tag == "else" {
            if branch-children.len() > 0 {
              stack.push((
                node: node,
                state: "choose-pending",
                meta: (child-count: branch-children.len()),
              ))
              let j = branch-children.len() - 1
              while j >= 0 {
                stack.push((
                  node: branch-children.at(j),
                  state: "pending",
                  meta: (:),
                ))
                j -= 1
              }
            } else {
              results.push([])
            }
            break
          }
        }
        // If no branch matched, push empty result
        if stack.len() == 0 or stack.last().state != "choose-pending" {
          results.push([])
        }
      } else {
        // Leaf node - process immediately
        results.push(process-leaf(node, ctx))
      }
    } else if state == "macro-pending" {
      // Macro children completed, collect results
      let child-count = meta.child-count
      let collected = ()
      let k = 0
      while k < child-count {
        if results.len() > 0 {
          collected.push(results.pop())
        }
        k += 1
      }
      // Reverse to get correct order
      let ordered = ()
      let m = collected.len() - 1
      while m >= 0 {
        ordered.push(collected.at(m))
        m -= 1
      }
      // Join non-empty results
      let joined = ordered.filter(x => not is-empty(x)).join()

      // Cache the raw result (without formatting)
      macro-cache.insert(meta.macro-name, joined)

      // Apply formatting and push
      results.push(finalize(joined, meta.attrs))
    } else if state == "group-pending" {
      // Group children completed
      let child-count = meta.child-count
      let collected = ()
      let k = 0
      while k < child-count {
        if results.len() > 0 {
          collected.push(results.pop())
        }
        k += 1
      }
      // Reverse
      let ordered = ()
      let m = collected.len() - 1
      while m >= 0 {
        ordered.push(collected.at(m))
        m -= 1
      }
      // Join with delimiter
      let delimiter = meta.attrs.at("delimiter", default: "")
      let parts = ordered.filter(x => not is-empty(x))
      let joined = if delimiter != "" and parts.len() > 1 {
        parts.join(delimiter)
      } else {
        parts.join()
      }

      // Apply prefix/suffix
      let prefix = meta.attrs.at("prefix", default: "")
      let suffix = meta.attrs.at("suffix", default: "")
      if not is-empty(joined) {
        results.push([#prefix#joined#suffix])
      } else {
        results.push([])
      }
    } else if state == "choose-pending" {
      // Choose branch completed
      let child-count = meta.child-count
      let collected = ()
      let k = 0
      while k < child-count {
        if results.len() > 0 {
          collected.push(results.pop())
        }
        k += 1
      }
      // Reverse and join
      let ordered = ()
      let m = collected.len() - 1
      while m >= 0 {
        ordered.push(collected.at(m))
        m -= 1
      }
      let joined = ordered.filter(x => not is-empty(x)).join()
      results.push(joined)
    }
  }

  // Final result: join all top-level results
  results.filter(x => not is-empty(x)).join()
}

/// Convenience function to interpret a single node with stack
#let interpret-node-stack(node, ctx) = {
  interpret-children-stack((node,), ctx)
}

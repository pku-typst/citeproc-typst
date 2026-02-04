// citrus - CSL-to-Typst Code Generator (Hybrid)
//
// Generates Typst code strings from CSL AST nodes.
// Uses hybrid approach: control flow is compiled, complex elements call helpers.
// The generated code follows the same (content, var-state, done-vars) protocol
// as the stack-based interpreter.

#import "../../data/variables.typ": get-variable

/// Escape a string for use in Typst string literals
#let escape-string(s) = {
  s
    .replace("\\", "\\\\")
    .replace("\"", "\\\"")
    .replace("\n", "\\n")
    .replace("\r", "\\r")
    .replace("\t", "\\t")
}

/// Escape a string for use in Typst content brackets [...]
/// Escapes special markup characters like _, *, #, etc.
#let escape-content(s) = {
  s
    .replace("\\", "\\\\")
    .replace("#", "\\#")
    .replace("_", "\\_")
    .replace("*", "\\*")
    .replace("`", "\\`")
    .replace("$", "\\$")
    .replace("@", "\\@")
    .replace("<", "\\<")
    .replace(">", "\\>")
}

/// Serialize a value to Typst code string (handles all types recursively)
#let serialize-value(v) = {
  if type(v) == str {
    "\"" + escape-string(v) + "\""
  } else if type(v) == bool {
    if v { "true" } else { "false" }
  } else if type(v) == int or type(v) == float {
    str(v)
  } else if type(v) == array {
    if v.len() == 0 { "()" } else {
      let items = v.map(item => serialize-value(item))
      "(" + items.join(", ") + if items.len() == 1 { "," } else { "" } + ")"
    }
  } else if type(v) == dictionary {
    if v.len() == 0 { "(: )" } else {
      let pairs = ()
      for (k, val) in v.pairs() {
        pairs.push("\"" + escape-string(k) + "\": " + serialize-value(val))
      }
      "(" + pairs.join(", ") + ")"
    }
  } else {
    "none"
  }
}

/// Serialize a dictionary to Typst code string
#let serialize-dict(d) = serialize-value(d)

/// Serialize an array to Typst code string
#let serialize-array(arr) = serialize-value(arr)

/// Emit sequential evaluation for children with done-vars propagation
#let compile-children-seq(
  children,
  macros,
  depth,
  compile-fn,
  results-name: "results",
  done-name: "done",
) = {
  let indent = "  " * depth
  let code = ""
  code += indent + "let " + results-name + " = ()\n"
  code += (
    indent + "let " + done-name + " = ctx.at(\"done-vars\", default: ())\n"
  )

  for child in children {
    code += indent + "{\n"
    code += indent + "  let child-ctx = (..ctx, done-vars: " + done-name + ")\n"
    code += indent + "  let (content, state, child-done) = {\n"
    code += indent + "    let ctx = child-ctx\n"
    code += compile-fn(child, macros, depth: depth + 3) + "\n"
    code += indent + "  }\n"
    code += indent + "  " + done-name + " = " + done-name + " + child-done\n"
    code += (
      indent + "  " + results-name + ".push((content, state, child-done))\n"
    )
    code += indent + "}\n"
  }
  code
}

/// Compile condition expression
/// Instead of regenerating all condition logic, just call the interpreter's eval-condition
#let compile-condition(attrs) = {
  // Serialize attrs dict as Typst code
  let parts = ()
  for (key, val) in attrs {
    parts.push("\"" + escape-string(key) + "\": \"" + escape-string(val) + "\"")
  }
  "eval-condition((" + parts.join(", ") + ",), ctx)"
}

/// Emit a macro call with optional cache usage
#let compile-macro-call(macro-name, indent, prefix: "", suffix: "") = {
  let macro-key = escape-string(macro-name)
  let cache-setup = (
    indent
      + "  let macro-cache = if \"compiled-macro-cache\" in ctx {\n"
      + indent
      + "    ctx.compiled-macro-cache\n"
      + indent
      + "  } else {\n"
      + indent
      + "    (:)\n"
      + indent
      + "  }\n"
  )
  let cache-fetch = (
    indent
      + "  let result = if \""
      + macro-key
      + "\" in macro-cache {\n"
      + indent
      + "    macro-cache.at(\""
      + macro-key
      + "\")\n"
      + indent
      + "  } else {\n"
      + indent
      + "    let computed = ctx.compiled-macros.at(\""
      + macro-key
      + "\")(ctx)\n"
      + indent
      + "    macro-cache.insert(\""
      + macro-key
      + "\", computed)\n"
      + indent
      + "    computed\n"
      + indent
      + "  }\n"
  )

  if prefix == "" and suffix == "" {
    let code = indent + "{\n"
    code += cache-setup
    code += cache-fetch
    code += indent + "  result\n"
    code += indent + "}"
    code
  } else {
    let code = indent + "{\n"
    code += cache-setup
    code += cache-fetch
    code += indent + "  let (content, state, done) = result\n"
    code += (
      indent + "  if content != [] and content != none and content != \"\" {\n"
    )
    code += (
      indent
        + "    (["
        + escape-content(prefix)
        + "#content"
        + escape-content(suffix)
        + "], state, done)\n"
    )
    code += indent + "  } else {\n"
    code += indent + "    ([], state, done)\n"
    code += indent + "  }\n"
    code += indent + "}"
    code
  }
}

/// Main recursive compiler function
/// Handles all CSL node types in a single function to avoid forward declaration issues
#let compile-ast(node, macros, depth: 0) = {
  let indent = "  " * depth

  // Handle string nodes
  if type(node) == str {
    let trimmed = node.trim()
    if trimmed == "" {
      return indent + "([], \"none\", ())"
    } else {
      return indent + "([" + escape-content(trimmed) + "], \"none\", ())"
    }
  }

  // Handle non-dict nodes
  if type(node) != dictionary {
    return indent + "([], \"none\", ())"
  }

  let tag = node.at("tag", default: "")
  let attrs = node.at("attrs", default: (:))
  let children = node.at("children", default: ())

  // ==========================================================================
  // <text> element
  // ==========================================================================
  if tag == "text" {
    if "variable" in attrs {
      // Call helper for variable lookup with full formatting support
      let attrs-str = serialize-dict(attrs)
      return indent + "get-text-variable(ctx, " + attrs-str + ")"
    } else if "value" in attrs {
      // Literal value - inline for simplicity
      let attrs-str = serialize-dict(attrs)
      return (
        indent
          + "(finalize(["
          + escape-content(attrs.value)
          + "], "
          + attrs-str
          + "), \"none\", ())"
      )
    } else if "term" in attrs {
      // Call helper for term lookup
      let attrs-str = serialize-dict(attrs)
      return indent + "get-term(ctx, " + attrs-str + ")"
    } else if "macro" in attrs {
      let macro-name = attrs.macro
      let prefix = attrs.at("prefix", default: "")
      let suffix = attrs.at("suffix", default: "")

      return compile-macro-call(
        macro-name,
        indent,
        prefix: prefix,
        suffix: suffix,
      )
    } else {
      return indent + "([], \"none\", ())"
    }
  }

  // ==========================================================================
  // <group> element
  // ==========================================================================
  if tag == "group" {
    let delimiter = attrs.at("delimiter", default: "")
    let prefix = attrs.at("prefix", default: "")
    let suffix = attrs.at("suffix", default: "")

    // Filter valid children
    let valid-children = children.filter(c => (
      type(c) == dictionary and c.at("tag", default: "") != ""
    ))

    if valid-children.len() == 0 {
      return indent + "([], \"none\", ())"
    }

    let code = indent + "{\n"
    code += compile-children-seq(
      valid-children,
      macros,
      depth + 1,
      compile-ast,
      results-name: "results",
      done-name: "done",
    )
    code += indent + "  let states = results.map(r => r.at(1))\n"
    code += indent + "  let has-var = states.any(s => s == \"var\")\n"
    code += indent + "  let has-no-var = states.any(s => s == \"no-var\")\n"
    code += indent + "  if (has-var or has-no-var) and not has-var {\n"
    code += (
      indent + "    ([], \"no-var\", results.map(r => r.at(2)).flatten())\n"
    )
    code += indent + "  } else {\n"
    code += (
      indent
        + "    let contents = results.map(r => r.at(0)).filter(x => x != [] and x != none and x != \"\")\n"
    )

    if delimiter != "" {
      code += (
        indent
          + "    let joined = contents.join(\""
          + escape-string(delimiter)
          + "\")\n"
      )
    } else {
      code += indent + "    let joined = contents.join()\n"
    }

    if prefix != "" or suffix != "" {
      code += (
        indent + "    if joined != [] and joined != none and joined != \"\" {\n"
      )
      code += (
        indent
          + "      (["
          + escape-content(prefix)
          + "#joined"
          + escape-content(suffix)
          + "], if has-var { \"var\" } else { \"none\" }, results.map(r => r.at(2)).flatten())\n"
      )
      code += indent + "    } else {\n"
      code += (
        indent
          + "      ([], if has-var { \"var\" } else { \"none\" }, results.map(r => r.at(2)).flatten())\n"
      )
      code += indent + "    }\n"
    } else {
      code += (
        indent
          + "    (joined, if has-var { \"var\" } else { \"none\" }, results.map(r => r.at(2)).flatten())\n"
      )
    }

    code += indent + "  }\n"
    code += indent + "}"
    return code
  }

  // ==========================================================================
  // <choose> element
  // ==========================================================================
  if tag == "choose" {
    let code = indent + "{\n"
    let first = true

    for branch in children {
      if type(branch) != dictionary { continue }
      let branch-tag = branch.at("tag", default: "")
      let branch-attrs = branch.at("attrs", default: (:))
      let branch-children = branch.at("children", default: ())

      // Filter valid branch children
      let valid-branch-children = branch-children.filter(c => (
        type(c) == dictionary and c.at("tag", default: "") != ""
      ))

      if branch-tag == "if" or branch-tag == "else-if" {
        let condition = compile-condition(branch-attrs)

        if first {
          code += indent + "  if " + condition + " {\n"
          first = false
        } else {
          code += indent + "  } else if " + condition + " {\n"
        }

        // Compile branch children
        if valid-branch-children.len() == 1 {
          code += (
            compile-ast(valid-branch-children.first(), macros, depth: depth + 2)
              + "\n"
          )
        } else if valid-branch-children.len() > 1 {
          code += indent + "    {\n"
          code += compile-children-seq(
            valid-branch-children,
            macros,
            depth + 3,
            compile-ast,
            results-name: "results",
            done-name: "done",
          )
          code += (
            indent
              + "      let contents = results.map(r => r.at(0)).filter(x => x != [] and x != none and x != \"\")\n"
          )
          code += indent + "      let states = results.map(r => r.at(1))\n"
          code += (
            indent
              + "      let merged = if states.any(s => s == \"var\") { \"var\" } else if states.any(s => s == \"no-var\") { \"no-var\" } else { \"none\" }\n"
          )
          code += (
            indent
              + "      (contents.join(), merged, results.map(r => r.at(2)).flatten())\n"
          )
          code += indent + "    }\n"
        } else {
          code += indent + "    ([], \"none\", ())\n"
        }
      } else if branch-tag == "else" {
        code += indent + "  } else {\n"

        if valid-branch-children.len() == 1 {
          code += (
            compile-ast(valid-branch-children.first(), macros, depth: depth + 2)
              + "\n"
          )
        } else if valid-branch-children.len() > 1 {
          code += indent + "    {\n"
          code += compile-children-seq(
            valid-branch-children,
            macros,
            depth + 3,
            compile-ast,
            results-name: "results",
            done-name: "done",
          )
          code += (
            indent
              + "      let contents = results.map(r => r.at(0)).filter(x => x != [] and x != none and x != \"\")\n"
          )
          code += indent + "      let states = results.map(r => r.at(1))\n"
          code += (
            indent
              + "      let merged = if states.any(s => s == \"var\") { \"var\" } else if states.any(s => s == \"no-var\") { \"no-var\" } else { \"none\" }\n"
          )
          code += (
            indent
              + "      (contents.join(), merged, results.map(r => r.at(2)).flatten())\n"
          )
          code += indent + "    }\n"
        } else {
          code += indent + "    ([], \"none\", ())\n"
        }
      }
    }

    if not first {
      // Check if we have an else branch already
      let has-else = children.any(b => (
        type(b) == dictionary and b.at("tag", default: "") == "else"
      ))
      if not has-else {
        // Add default else branch to ensure we always return a tuple
        code += indent + "  } else {\n"
        code += indent + "    ([], \"none\", ())\n"
      }
      code += indent + "  }\n"
    } else {
      code += indent + "  ([], \"none\", ())\n"
    }

    code += indent + "}"
    return code
  }

  // ==========================================================================
  // <names> element - calls format-names helper
  // ==========================================================================
  if tag == "names" {
    let attrs-str = serialize-dict(attrs)
    let children-str = serialize-array(children)

    let var-str = attrs.at("variable", default: "author")
    let single-var = not var-str.contains(" ")
    let var-list = var-str.split(" ")

    let has-substitute = children.any(c => (
      type(c) == dictionary and c.at("tag", default: "") == "substitute"
    ))

    let allowed-children = children.all(c => (
      type(c) == dictionary
        and c.at("tag", default: "")
          in ("name", "label", "et-al", "institution")
    ))

    let name-node = children.find(c => (
      type(c) == dictionary and c.at("tag", default: "") == "name"
    ))
    let label-node = children.find(c => (
      type(c) == dictionary and c.at("tag", default: "") == "label"
    ))
    let substitute-node = children.find(c => (
      type(c) == dictionary and c.at("tag", default: "") == "substitute"
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

    let et-al-node = children.find(c => (
      type(c) == dictionary and c.at("tag", default: "") == "et-al"
    ))
    let et-al-attrs = if et-al-node != none {
      et-al-node.at("attrs", default: (:))
    } else { (:) }
    let et-al-term = et-al-attrs.at("term", default: "et-al")

    let label-attrs = if label-node != none {
      label-node.at("attrs", default: (:))
    } else { (:) }
    let has-label = label-node != none
    let label-position = if label-node != none and name-node != none {
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

    let institution-node = children.find(c => (
      type(c) == dictionary and c.at("tag", default: "") == "institution"
    ))
    let institution-attrs = if institution-node != none {
      institution-node.at("attrs", default: (:))
    } else { none }

    let substitute-children = if substitute-node != none {
      substitute-node.at("children", default: ())
    } else { () }

    let plan = (
      var: var-str,
      vars: var-list,
      names-delimiter: attrs.at("delimiter", default: none),
      name-attrs: name-attrs,
      name-parts: name-parts,
      et-al-attrs: et-al-attrs,
      et-al-term: et-al-term,
      label-attrs: label-attrs,
      label-position: label-position,
      has-label: has-label,
      institution-attrs: institution-attrs,
      parent-name-node: name-node,
      parent-label-node: label-node,
      substitute-children: substitute-children,
    )
    let plan-str = serialize-dict(plan)

    if has-substitute {
      return (
        indent
          + "format-names-substitute(ctx, "
          + attrs-str
          + ", "
          + plan-str
          + ")"
      )
    }

    if not has-substitute and allowed-children {
      if single-var {
        return (
          indent
            + "format-names-single(ctx, "
            + attrs-str
            + ", "
            + plan-str
            + ")"
        )
      } else {
        return (
          indent
            + "format-names-multi(ctx, "
            + attrs-str
            + ", "
            + plan-str
            + ")"
        )
      }
    }

    return indent + "format-names(ctx, " + attrs-str + ", " + children-str + ")"
  }

  // ==========================================================================
  // <date> element - calls format-date helper
  // ==========================================================================
  if tag == "date" {
    // Serialize attrs and children for the helper call
    let attrs-str = serialize-dict(attrs)
    let children-str = serialize-array(children)

    return indent + "format-date(ctx, " + attrs-str + ", " + children-str + ")"
  }

  // ==========================================================================
  // <number> element - compiled form specialization
  // ==========================================================================
  if tag == "number" {
    let attrs-str = serialize-dict(attrs)
    let form = attrs.at("form", default: "numeric")
    let helper = if form == "ordinal" {
      "format-number-ordinal"
    } else if form == "long-ordinal" {
      "format-number-long-ordinal"
    } else if form == "roman" {
      "format-number-roman"
    } else {
      "format-number-numeric"
    }
    return indent + helper + "(ctx, " + attrs-str + ")"
  }

  // ==========================================================================
  // <label> element - calls format-label helper
  // ==========================================================================
  if tag == "label" {
    let attrs-str = serialize-dict(attrs)
    return indent + "format-label(ctx, " + attrs-str + ")"
  }

  // Unknown tag
  indent + "([], \"none\", ())"
}

/// Compile a macro definition
#let compile-macro(name, children, macros) = {
  // Filter valid children
  let valid-children = children.filter(c => (
    type(c) == dictionary and c.at("tag", default: "") != ""
  ))

  if valid-children.len() == 0 {
    return "(ctx) => ([], \"none\", ())"
  }

  if valid-children.len() == 1 {
    let code = "(ctx) => {\n"
    code += compile-ast(valid-children.first(), macros, depth: 1) + "\n"
    code += "}"
    return code
  }

  // Multiple children
  let code = "(ctx) => {\n"
  code += compile-children-seq(valid-children, macros, 1, compile-ast)
  code += "  let contents = results.map(r => r.at(0)).filter(x => x != [] and x != none and x != \"\")\n"
  code += "  let states = results.map(r => r.at(1))\n"
  code += "  let merged = if states.any(s => s == \"var\") { \"var\" } else if states.any(s => s == \"no-var\") { \"no-var\" } else { \"none\" }\n"
  code += "  (contents.join(), merged, results.map(r => r.at(2)).flatten())\n"
  code += "}"
  code
}

/// Compile layout children
#let compile-children(children, macros) = {
  let valid-children = children.filter(c => (
    type(c) == dictionary and c.at("tag", default: "") != ""
  ))

  if valid-children.len() == 0 {
    return "([], \"none\", ())"
  }

  if valid-children.len() == 1 {
    return compile-ast(valid-children.first(), macros, depth: 1)
  }

  // Multiple children
  let code = "{\n"
  code += compile-children-seq(valid-children, macros, 1, compile-ast)
  code += "  let contents = results.map(r => r.at(0)).filter(x => x != [] and x != none and x != \"\")\n"
  code += "  let states = results.map(r => r.at(1))\n"
  code += "  let merged = if states.any(s => s == \"var\") { \"var\" } else if states.any(s => s == \"no-var\") { \"no-var\" } else { \"none\" }\n"
  code += "  (contents.join(), merged, results.map(r => r.at(2)).flatten())\n"
  code += "}"
  code
}

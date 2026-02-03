// citrus - CSL-to-Typst Code Generator (Hybrid)
//
// Generates Typst code strings from CSL AST nodes.
// Uses hybrid approach: control flow is compiled, complex elements call helpers.
// The generated code follows the same (content, var-state, done-vars) protocol
// as the stack-based interpreter.

#import "../data/variables.typ": get-variable

/// Escape a string for use in Typst string literals
#let escape-string(s) = {
  s.replace("\\", "\\\\")
   .replace("\"", "\\\"")
   .replace("\n", "\\n")
   .replace("\r", "\\r")
   .replace("\t", "\\t")
}

/// Escape a string for use in Typst content brackets [...]
/// Escapes special markup characters like _, *, #, etc.
#let escape-content(s) = {
  s.replace("\\", "\\\\")
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
    if v.len() == 0 { "()" }
    else {
      let items = v.map(item => serialize-value(item))
      "(" + items.join(", ") + if items.len() == 1 { "," } else { "" } + ")"
    }
  } else if type(v) == dictionary {
    if v.len() == 0 { "(: )" }
    else {
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

/// Compile condition expression
#let compile-condition(attrs) = {
  let conditions = ()
  let match-type = attrs.at("match", default: "all")
  
  // Variable condition - use has-variable helper for proper field mapping
  if "variable" in attrs {
    let vars = attrs.variable.split(" ")
    for v in vars {
      // Name variables check parsed-names
      if v in ("author", "editor", "translator", "container-author", "reviewed-author") {
        conditions.push("ctx.at(\"parsed-names\", default: (:)).at(\"" + escape-string(v) + "\", default: ()).len() > 0")
      } else {
        // Use has-variable helper which handles field name mapping (DOI->doi, etc.)
        conditions.push("has-variable(ctx, \"" + escape-string(v) + "\")")
      }
    }
  }
  
  // Type condition
  if "type" in attrs {
    let types = attrs.type.split(" ")
    let type-checks = types.map(t => "ctx.entry-type == \"" + escape-string(t) + "\"")
    conditions.push("(" + type-checks.join(" or ") + ")")
  }
  
  // Is-numeric condition
  if "is-numeric" in attrs {
    let vars = attrs.at("is-numeric").split(" ")
    for v in vars {
      conditions.push("{ let val = ctx.fields.at(\"" + escape-string(v) + "\", default: \"\"); val.match(regex(\"^\\\\d\")) != none }")
    }
  }
  
  // Position condition
  if "position" in attrs {
    let pos = attrs.position
    if pos == "first" {
      conditions.push("ctx.at(\"position\", default: \"first\") == \"first\"")
    } else if pos == "subsequent" {
      conditions.push("ctx.at(\"position\", default: \"first\") != \"first\"")
    } else if pos == "ibid" {
      conditions.push("ctx.at(\"position\", default: \"first\") == \"ibid\"")
    } else if pos == "ibid-with-locator" {
      conditions.push("ctx.at(\"position\", default: \"first\") == \"ibid-with-locator\"")
    }
  }
  
  // Locator condition
  if "locator" in attrs {
    let locs = attrs.locator.split(" ")
    let loc-checks = locs.map(l => "ctx.at(\"locator-label\", default: \"page\") == \"" + escape-string(l) + "\"")
    conditions.push("(" + loc-checks.join(" or ") + ")")
  }
  
  // Disambiguate condition
  if "disambiguate" in attrs {
    let disamb = attrs.disambiguate
    if disamb == "true" {
      conditions.push("ctx.at(\"disambiguate\", default: false) == true")
    } else {
      conditions.push("ctx.at(\"disambiguate\", default: false) == false")
    }
  }
  
  if conditions.len() == 0 {
    return "true"
  }
  
  if match-type == "any" {
    "(" + conditions.join(" or ") + ")"
  } else if match-type == "none" {
    "not (" + conditions.join(" or ") + ")"
  } else {
    // "all" (default)
    "(" + conditions.join(" and ") + ")"
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
      return indent + "(finalize([" + escape-content(attrs.value) + "], " + attrs-str + "), \"none\", ())"
      
    } else if "term" in attrs {
      // Call helper for term lookup
      let attrs-str = serialize-dict(attrs)
      return indent + "get-term(ctx, " + attrs-str + ")"
      
    } else if "macro" in attrs {
      let macro-name = attrs.macro
      let prefix = attrs.at("prefix", default: "")
      let suffix = attrs.at("suffix", default: "")
      
      if prefix == "" and suffix == "" {
        return indent + "ctx.compiled-macros.at(\"" + escape-string(macro-name) + "\")(ctx)"
      } else {
        // Apply prefix/suffix to macro result
        let code = indent + "{\n"
        code += indent + "  let (content, state, done) = ctx.compiled-macros.at(\"" + escape-string(macro-name) + "\")(ctx)\n"
        code += indent + "  if content != [] and content != none and content != \"\" {\n"
        code += indent + "    ([" + escape-content(prefix) + "#content" + escape-content(suffix) + "], state, done)\n"
        code += indent + "  } else {\n"
        code += indent + "    ([], state, done)\n"
        code += indent + "  }\n"
        code += indent + "}"
        return code
      }
      
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
    code += indent + "  let results = (\n"
    
    for (i, child) in valid-children.enumerate() {
      code += compile-ast(child, macros, depth: depth + 2)
      code += ","  // Always add comma - required for single-element arrays in Typst
      code += "\n"
    }
    
    code += indent + "  )\n"
    code += indent + "  let states = results.map(r => r.at(1))\n"
    code += indent + "  let has-var = states.any(s => s == \"var\")\n"
    code += indent + "  let has-no-var = states.any(s => s == \"no-var\")\n"
    code += indent + "  if (has-var or has-no-var) and not has-var {\n"
    code += indent + "    ([], \"no-var\", results.map(r => r.at(2)).flatten())\n"
    code += indent + "  } else {\n"
    code += indent + "    let contents = results.map(r => r.at(0)).filter(x => x != [] and x != none and x != \"\")\n"
    
    if delimiter != "" {
      code += indent + "    let joined = contents.join(\"" + escape-string(delimiter) + "\")\n"
    } else {
      code += indent + "    let joined = contents.join()\n"
    }
    
    if prefix != "" or suffix != "" {
      code += indent + "    if joined != [] and joined != none and joined != \"\" {\n"
      code += indent + "      ([" + escape-content(prefix) + "#joined" + escape-content(suffix) + "], if has-var { \"var\" } else { \"none\" }, results.map(r => r.at(2)).flatten())\n"
      code += indent + "    } else {\n"
      code += indent + "      ([], if has-var { \"var\" } else { \"none\" }, results.map(r => r.at(2)).flatten())\n"
      code += indent + "    }\n"
    } else {
      code += indent + "    (joined, if has-var { \"var\" } else { \"none\" }, results.map(r => r.at(2)).flatten())\n"
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
          code += compile-ast(valid-branch-children.first(), macros, depth: depth + 2) + "\n"
        } else if valid-branch-children.len() > 1 {
          code += indent + "    {\n"
          code += indent + "      let results = (\n"
          for (i, child) in valid-branch-children.enumerate() {
            code += compile-ast(child, macros, depth: depth + 4)
            code += ","  // Always add comma for single-element array safety
            code += "\n"
          }
          code += indent + "      )\n"
          code += indent + "      let contents = results.map(r => r.at(0)).filter(x => x != [] and x != none and x != \"\")\n"
          code += indent + "      let states = results.map(r => r.at(1))\n"
          code += indent + "      let merged = if states.any(s => s == \"var\") { \"var\" } else if states.any(s => s == \"no-var\") { \"no-var\" } else { \"none\" }\n"
          code += indent + "      (contents.join(), merged, results.map(r => r.at(2)).flatten())\n"
          code += indent + "    }\n"
        } else {
          code += indent + "    ([], \"none\", ())\n"
        }
        
      } else if branch-tag == "else" {
        code += indent + "  } else {\n"
        
        if valid-branch-children.len() == 1 {
          code += compile-ast(valid-branch-children.first(), macros, depth: depth + 2) + "\n"
        } else if valid-branch-children.len() > 1 {
          code += indent + "    {\n"
          code += indent + "      let results = (\n"
          for (i, child) in valid-branch-children.enumerate() {
            code += compile-ast(child, macros, depth: depth + 4)
            code += ","  // Always add comma for single-element array safety
            code += "\n"
          }
          code += indent + "      )\n"
          code += indent + "      let contents = results.map(r => r.at(0)).filter(x => x != [] and x != none and x != \"\")\n"
          code += indent + "      let states = results.map(r => r.at(1))\n"
          code += indent + "      let merged = if states.any(s => s == \"var\") { \"var\" } else if states.any(s => s == \"no-var\") { \"no-var\" } else { \"none\" }\n"
          code += indent + "      (contents.join(), merged, results.map(r => r.at(2)).flatten())\n"
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
    // Serialize attrs and children for the helper call
    let attrs-str = serialize-dict(attrs)
    let children-str = serialize-array(children)
    
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
  // <number> element - calls format-number helper
  // ==========================================================================
  if tag == "number" {
    let attrs-str = serialize-dict(attrs)
    return indent + "format-number(ctx, " + attrs-str + ")"
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
  code += "  let results = (\n"
  for (i, child) in valid-children.enumerate() {
    code += compile-ast(child, macros, depth: 2)
    code += ","  // Always add comma for single-element array safety
    code += "\n"
  }
  code += "  )\n"
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
  code += "  let results = (\n"
  for (i, child) in valid-children.enumerate() {
    code += compile-ast(child, macros, depth: 2)
    code += ","  // Always add comma for single-element array safety
    code += "\n"
  }
  code += "  )\n"
  code += "  let contents = results.map(r => r.at(0)).filter(x => x != [] and x != none and x != \"\")\n"
  code += "  let states = results.map(r => r.at(1))\n"
  code += "  let merged = if states.any(s => s == \"var\") { \"var\" } else if states.any(s => s == \"no-var\") { \"no-var\" } else { \"none\" }\n"
  code += "  (contents.join(), merged, results.map(r => r.at(2)).flatten())\n"
  code += "}"
  code
}

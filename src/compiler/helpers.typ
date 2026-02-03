// citrus - Compiler Helpers
//
// Adapter functions that wrap existing interpreter handlers for use in compiled code.
// These functions are passed to eval() via the scope parameter.

#import "../interpreter/names.typ": handle-names as _handle-names
#import "../interpreter/date.typ": handle-date as _handle-date
#import "../interpreter/number.typ": handle-number as _handle-number, handle-label as _handle-label
#import "../core/mod.typ": finalize, is-empty, apply-text-case
#import "../parsing/mod.typ": lookup-term
#import "../text/quotes.typ": apply-quotes, transform-quotes-at-level
#import "../text/ranges.typ": format-page-range
#import "../data/variables.typ": get-variable

// =============================================================================
// Names Helper
// =============================================================================

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
    let has-any = var-names.any(v => ctx.at("parsed-names", default: (:)).at(v, default: ()).len() > 0)
    if has-any { "var" } else { "no-var" }
  } else {
    "var"
  }
  
  (content, var-state, done-vars)
}

// =============================================================================
// Date Helper
// =============================================================================

/// Format date from a CSL <date> element
/// This is the hybrid adapter that calls the full interpreter implementation.
///
/// - ctx: Context dictionary with fields, locale, year-suffix, etc.
/// - attrs: Dictionary of CSL attributes (variable, form, date-parts, etc.)
/// - children: Array of child nodes (date-part elements)
/// Returns: (content, var-state, done-vars) tuple
#let format-date-compiled(ctx, attrs, children) = {
  // Build a node structure that the interpreter expects
  let node = (
    tag: "date",
    attrs: attrs,
    children: children,
  )
  
  // Call the interpreter's handle-date
  let content = _handle-date(node, ctx)
  
  // Determine var-state based on output
  let var-state = if is-empty(content) { "no-var" } else { "var" }
  
  (content, var-state, ())
}

// =============================================================================
// Number Helper
// =============================================================================

/// Format number from a CSL <number> element
///
/// - ctx: Context dictionary with fields
/// - attrs: Dictionary of CSL attributes (variable, form, etc.)
/// Returns: (content, var-state, done-vars) tuple
#let format-number-compiled(ctx, attrs) = {
  // Build a node structure that the interpreter expects
  let node = (
    tag: "number",
    attrs: attrs,
    children: (),
  )
  
  // Stub interpret function (number doesn't have children)
  let stub-interpret(children, c) = []
  
  // Call the interpreter's handle-number
  let content = _handle-number(node, ctx, stub-interpret)
  
  // Determine var-state based on output
  let var-state = if is-empty(content) { "no-var" } else { "var" }
  
  (content, var-state, ())
}

// =============================================================================
// Label Helper
// =============================================================================

/// Format label from a CSL <label> element
///
/// - ctx: Context dictionary with locale
/// - attrs: Dictionary of CSL attributes (variable, form, plural, etc.)
/// Returns: (content, var-state, done-vars) tuple
#let format-label-compiled(ctx, attrs) = {
  // Build a node structure that the interpreter expects
  let node = (
    tag: "label",
    attrs: attrs,
    children: (),
  )
  
  // Stub interpret function (label doesn't have children)
  let stub-interpret(children, c) = []
  
  // Call the interpreter's handle-label
  let content = _handle-label(node, ctx, stub-interpret)
  
  // Determine var-state based on output
  let var-state = if is-empty(content) { "no-var" } else { "none" }
  
  (content, var-state, ())
}

// =============================================================================
// Text Variable Helper
// =============================================================================

/// Get text variable value
///
/// - ctx: Context dictionary with fields and done-vars
/// - attrs: Dictionary of CSL attributes (variable, form, etc.)
/// Returns: (content, var-state, done-vars) tuple
#let get-text-variable(ctx, attrs) = {
  let var-name = attrs.at("variable", default: "")
  let form = attrs.at("form", default: "long")
  
  // Check if already rendered (done-vars quashing)
  if var-name in ctx.at("done-vars", default: ()) {
    return ([], "none", ())
  }
  
  // Special handling for year-suffix - it's in ctx, not ctx.fields
  if var-name == "year-suffix" {
    let suffix = ctx.at("year-suffix", default: none)
    if suffix != none and suffix != "" {
      // Convert numeric suffix to letter (0 -> "a", 1 -> "b", etc.)
      import "../data/collapsing.typ": num-to-suffix
      let suffix-str = if type(suffix) == int {
        num-to-suffix(suffix)
      } else {
        str(suffix)
      }
      return (finalize(suffix-str, attrs), "var", ())
    } else {
      return ([], "no-var", ())
    }
  }
  
  // Get value using get-variable which handles field name mapping
  // (e.g., DOI -> doi, URL -> url)
  let val = get-variable(ctx, var-name)
  
  // Handle short form
  let val = if form == "short" and val == "" {
    get-variable(ctx, var-name + "-short")
  } else { val }
  
  if val != "" {
    // Format page ranges for page, page-first, locator
    let formatted = if var-name == "page" or var-name == "page-first" or var-name == "locator" {
      let page-format = if "style" in ctx {
        ctx.style.at("page-range-format", default: none)
      } else { none }
      format-page-range(val, format: page-format, ctx: ctx)
    } else { val }
    
    // Apply text-case FIRST while content is still a string
    let cased = apply-text-case(formatted, attrs, ctx: ctx)
    
    // Handle quotes (CSL quote flipflopping)
    let quote-level = ctx.at("quote-level", default: 0)
    let has-quotes = attrs.at("quotes", default: "false") == "true"
    
    // Normalize embedded quotes in content (only if ctx.style is available)
    let normalized = if type(cased) == str and "style" in ctx {
      if has-quotes {
        // Will add outer quotes, so embedded quotes go to level+1
        transform-quotes-at-level(cased, ctx, quote-level + 1)
      } else {
        // No outer quotes, normalize to current level
        transform-quotes-at-level(cased, ctx, quote-level)
      }
    } else { cased }
    
    // Apply quotes if requested (only if ctx.style is available)
    let quoted = if has-quotes and "style" in ctx {
      apply-quotes(normalized, ctx, level: quote-level)
    } else { normalized }
    
    (finalize(quoted, attrs), "var", ())
  } else {
    ([], "no-var", ())
  }
}

// =============================================================================
// Term Helper
// =============================================================================

/// Get term value
///
/// - ctx: Context dictionary with locale
/// - attrs: Dictionary of CSL attributes (term, form, plural, etc.)
/// Returns: (content, var-state, done-vars) tuple
#let get-term-compiled(ctx, attrs) = {
  let term-name = attrs.at("term", default: "")
  let form = attrs.at("form", default: "long")
  let plural = attrs.at("plural", default: "false") == "true"
  
  let term = lookup-term(ctx, term-name, form: form, plural: plural)
  if term != none {
    (finalize(term, attrs), "none", ())
  } else {
    ([], "none", ())
  }
}

// =============================================================================
// Condition Helpers
// =============================================================================

/// Check if a variable has a non-empty value
/// Uses get-variable to handle field name mapping (DOI -> doi, etc.)
#let has-variable(ctx, var-name) = {
  get-variable(ctx, var-name) != ""
}

// =============================================================================
// Helper Dictionary for eval() scope
// =============================================================================

/// All helpers bundled for passing to eval()
#let compiler-helpers = (
  format-names: format-names-compiled,
  format-date: format-date-compiled,
  format-number: format-number-compiled,
  format-label: format-label-compiled,
  get-text-variable: get-text-variable,
  get-term: get-term-compiled,
  has-variable: has-variable,
  finalize: finalize,
  is-empty: is-empty,
  lookup-term: lookup-term,
)

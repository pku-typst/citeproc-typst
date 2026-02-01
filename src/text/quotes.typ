// citrus - Quote Handling Module
//
// Implements CSL quote flipflopping:
// - Alternates between outer and inner quotes for nested quotations
// - Handles locale-specific quote marks

#import "../parsing/mod.typ": get-quote-chars

// =============================================================================
// Quote Functions
// =============================================================================

/// Apply quotes to text content
///
/// - text: The text to quote
/// - ctx: Context with locale info
/// - level: Nesting level (0 = outer quotes, 1 = inner quotes, etc.)
/// Returns: Quoted text
#let apply-quotes(text, ctx, level: 0) = {
  if text == none or text == "" or text == [] { return text }

  let lang = ctx.style.at("default-locale", default: "en")
  let chars = get-quote-chars(lang)

  // Alternate between outer and inner quotes based on level
  let is-inner = calc.rem(level, 2) == 1

  let open = if is-inner { chars.open-inner-quote } else { chars.open-quote }
  let close = if is-inner { chars.close-inner-quote } else { chars.close-quote }

  [#open#text#close]
}

/// Count quote nesting level in a string
///
/// Counts how many levels deep we are in quotes
///
/// - text: Text to analyze
/// - ctx: Context with locale info
/// Returns: Integer nesting level
#let count-quote-nesting(text, ctx) = {
  if text == none or type(text) != str { return 0 }

  let lang = ctx.style.at("default-locale", default: "en")
  let chars = get-quote-chars(lang)

  let level = 0
  let max-level = 0

  for char in text {
    if (
      char == chars.open-quote.first() or char == chars.open-inner-quote.first()
    ) {
      level += 1
      if level > max-level { max-level = level }
    } else if (
      char == chars.close-quote.first()
        or char == chars.close-inner-quote.first()
    ) {
      level -= 1
    }
  }

  max-level
}

/// Transform quotes in text to use proper marks for the given nesting level
///
/// When we're inside outer quotes (level 1), embedded double quotes should become single.
/// When we're inside inner quotes (level 2), embedded quotes become double again, etc.
///
/// - text: Text with quotes
/// - ctx: Context with locale info
/// - level: Current quote nesting level (0 = not inside quotes, 1 = inside outer quotes, etc.)
/// Returns: Text with quotes transformed for the given level
#let transform-quotes-at-level(text, ctx, level) = {
  if text == none or type(text) != str { return text }
  if level == 0 { return text } // No transformation needed at level 0

  let lang = ctx.style.at("default-locale", default: "en")
  let chars = get-quote-chars(lang)

  // Unicode quote characters for detection
  let left-double = "\u{201C}" // "
  let right-double = "\u{201D}" // "
  let straight-double = "\""
  let left-single = "\u{2018}" // '
  let right-single = "\u{2019}" // '

  // Determine target quotes based on level mod 2
  // At level 1 (inside outer quotes): double -> single
  // At level 2 (inside inner quotes): use double again
  let use-inner = calc.rem(level, 2) == 1
  let target-open = if use-inner { chars.open-inner-quote } else {
    chars.open-quote
  }
  let target-close = if use-inner { chars.close-inner-quote } else {
    chars.close-quote
  }

  let result = ""

  // Transform double quotes to appropriate level
  for char in text.clusters() {
    if char == left-double or char == straight-double {
      // Opening double quote -> transform to current level
      result += target-open
    } else if char == right-double {
      // Closing double quote -> transform to current level
      result += target-close
    } else if char == left-single {
      // Single quotes: if we're at level 1, these should become double (opposite)
      if use-inner {
        result += chars.open-quote
      } else {
        result += chars.open-inner-quote
      }
    } else if char == right-single {
      // Could be apostrophe - only transform if it's a closing quote
      // For now, treat as closing quote
      if use-inner {
        result += chars.close-quote
      } else {
        result += chars.close-inner-quote
      }
    } else {
      result += char
    }
  }

  result
}

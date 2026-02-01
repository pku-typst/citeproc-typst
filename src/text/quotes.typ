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
/// CSL spec: quotes in field content are normalized to the appropriate level:
/// - Level 0 (outermost): single quotes in content become double quotes
/// - Level 1 (inside outer quotes): double quotes in content become single quotes
/// - Level 2 (inside inner quotes): single quotes become double again, etc.
///
/// IMPORTANT: Apostrophes (right single quote ' in contractions like "don't")
/// should NOT be transformed. We detect apostrophes by checking if they're
/// between letters (not at word boundaries).
///
/// - text: Text with quotes
/// - ctx: Context with locale info
/// - level: Current quote nesting level (0 = outermost, 1 = inside outer quotes, etc.)
/// Returns: Text with quotes transformed for the given level
#let transform-quotes-at-level(text, ctx, level) = {
  if text == none or type(text) != str { return text }

  let lang = ctx.style.at("default-locale", default: "en")
  let chars = get-quote-chars(lang)

  // Unicode quote characters for detection
  let left-double = "\u{201C}" // "
  let right-double = "\u{201D}" // "
  let straight-double = "\""
  let left-single = "\u{2018}" // '
  let right-single = "\u{2019}" // ' (also apostrophe!)
  let straight-single = "'"

  // Determine target quotes based on level mod 2
  // Level 0: outer quotes (double), Level 1: inner quotes (single), etc.
  let use-inner = calc.rem(level, 2) == 1
  let target-open = if use-inner { chars.open-inner-quote } else { chars.open-quote }
  let target-close = if use-inner { chars.close-inner-quote } else { chars.close-quote }

  let clusters = text.clusters()
  let result = ""
  let letter-pattern = regex("[a-zA-Z\u{00C0}-\u{024F}]")

  for (i, char) in clusters.enumerate() {
    // Check previous and next characters for apostrophe detection
    let prev = if i > 0 { clusters.at(i - 1) } else { "" }
    let next = if i < clusters.len() - 1 { clusters.at(i + 1) } else { "" }
    let prev-is-letter = prev.match(letter-pattern) != none
    let next-is-letter = next.match(letter-pattern) != none

    if char == left-double or char == straight-double {
      // Double quote -> transform to target level
      result += target-open
    } else if char == right-double {
      // Closing double quote -> transform to target level
      result += target-close
    } else if char == left-single or (char == straight-single and not prev-is-letter) {
      // Opening single quote or straight apostrophe at start of word
      // Check if this looks like a leading apostrophe (e.g., '09, 'twas)
      // Leading apostrophe: followed by digit or lowercase letter, not preceded by letter
      let next-is-digit = next.match(regex("[0-9]")) != none
      let next-is-lower = next.match(regex("[a-z\u{00E0}-\u{00FF}]")) != none
      if not prev-is-letter and (next-is-digit or next-is-lower) {
        // This is a leading apostrophe (contraction like '09, 'twas), keep as-is
        result += right-single // Use typographic apostrophe
      } else {
        // This is an opening quote
        if use-inner {
          result += chars.open-inner-quote
        } else {
          result += chars.open-quote
        }
      }
    } else if char == right-single or char == straight-single {
      // Right single quote or straight apostrophe
      // Need to distinguish between closing quote and apostrophe
      // Apostrophe: between letters (e.g., "don't", "it's", "l'Égypte")
      if prev-is-letter and next-is-letter {
        // This is an apostrophe, keep as-is
        result += right-single // Use typographic apostrophe
      } else if prev-is-letter and not next-is-letter {
        // End of word with apostrophe - could be closing quote or trailing apostrophe
        // Check if previous char sequence looks like a quoted word
        // For now, treat as closing quote
        if use-inner {
          result += chars.close-inner-quote
        } else {
          result += chars.close-quote
        }
      } else {
        // Other cases - keep as apostrophe
        result += right-single
      }
    } else {
      result += char
    }
  }

  result
}

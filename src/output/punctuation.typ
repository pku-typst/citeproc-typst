// citrus - Punctuation Collapsing
//
// Implements CSL punctuation collapsing rules based on citeproc-js LtoR_MAP.

/// Get the punctuation-in-quote setting from a parsed CSL style
///
/// - style: Parsed CSL style
/// Returns: Boolean indicating whether punctuation should be moved inside quotes
#let get-punctuation-in-quote(style) = {
  // Check style.locale.options first (merged locale)
  let locale = style.at("locale", default: (:))
  let options = locale.at("options", default: (:))
  options.at("punctuation-in-quote", default: false)
}

/// Apply CSL punctuation collapsing to content
///
/// Based on citeproc-js LtoR_MAP logic. The map defines what happens when
/// two punctuation marks are adjacent (left + right → result).
///
/// Absorption rules (from citeproc-js):
/// - "!" absorbs "." and ":"    → !. → !,  !: → !
/// - "?" absorbs "." and ":"    → ?. → ?,  ?: → ?
/// - ":" absorbs "."            → :. → :
/// - ":" absorbed by "!" "?"    → :! → !,  :? → ?
/// - ";" absorbs "." and ":"    → ;. → ;,  ;: → ;
/// - ";" absorbed by "!" "?"    → ;! → !,  ;? → ?
/// - "," absorbs "."            → ,. → ,
///
/// All other combinations keep both characters.
///
/// punctuation-in-quote option (CSL locale setting):
/// When true, periods and commas are moved inside closing quotation marks.
/// - "Title". → "Title."
/// - "Title", → "Title,"
///
/// This wrapper limits the show rules to CSL output only.
#let collapse-punctuation(content, punctuation-in-quote: false) = {
  // Rule 0: Multiple spaces collapse to single space
  // This handles cases like delimiter ". " + prefix " (" → ". (" not ".  ("
  show regex(" {2,}"): " "

  // Rule 1: Duplicate punctuation collapses (keeps first character)
  show regex("[.。]{2,}"): it => it.text.first()
  show regex("[,，、]{2,}"): it => it.text.first()
  show regex("[;；]{2,}"): it => it.text.first()
  show regex("[:：]{2,}"): it => it.text.first()
  show regex("[!！]{2,}"): it => it.text.first()
  show regex("[?？]{2,}"): it => it.text.first()

  // Rule 2: Absorption rules from citeproc-js LtoR_MAP
  // Helper to get the "stronger" punctuation
  let get-absorbed(text, absorbers) = {
    let chars = text.clusters()
    chars.find(c => c in absorbers)
  }

  // "!" absorbs "." and ":"
  show regex("[!！][.。]"): it => it.text.first()
  show regex("[!！][:：]"): it => it.text.first()

  // "?" absorbs "." and ":"
  show regex("[?？][.。]"): it => it.text.first()
  show regex("[?？][:：]"): it => it.text.first()

  // ":" absorbs "." only
  show regex("[:：][.。]"): it => it.text.first()

  // ":" is absorbed by "!" and "?"
  show regex("[:：][!！]"): it => it.text.clusters().last()
  show regex("[:：][?？]"): it => it.text.clusters().last()

  // ";" absorbs "." and ":"
  show regex("[;；][.。]"): it => it.text.first()
  show regex("[;；][:：]"): it => it.text.first()

  // ";" is absorbed by "!" and "?"
  show regex("[;；][!！]"): it => it.text.clusters().last()
  show regex("[;；][?？]"): it => it.text.clusters().last()

  // "," absorbs "."
  show regex("[,，、][.。]"): it => it.text.first()

  // punctuation-in-quote: move periods and commas inside closing quotes
  // Only applies when the locale has punctuation-in-quote="true" (e.g., en-US)
  // Pattern: closing quote followed by period or comma → swap them
  // Handles: " (right double quote)
  // Note: We handle this conditionally by wrapping in another layer
  if punctuation-in-quote {
    // Right double quote + period/comma → swap them
    show "\u{201D}.": ".\u{201D}"
    show "\u{201D},": ",\u{201D}"
    content
  } else {
    content
  }
}

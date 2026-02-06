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
#import "helpers.typ": content-to-string

#let _is-plain-text(content) = {
  if content == none or content == [] { return true }
  if type(content) == str { return true }
  let func = content.func()
  let fields = content.fields()

  if func == text {
    let body = fields.at("body", default: fields.at("text", default: ""))
    return _is-plain-text(body)
  }

  if "children" in fields {
    return fields.children.all(_is-plain-text)
  }

  false
}

#let collapse-punctuation(content, punctuation-in-quote: false) = {
  // Apply punctuation rules inside links by recursing into the body
  if content != none and type(content) != str and content.func() == link {
    let fields = content.fields()
    let dest = fields.at("dest", default: none)
    let body = fields.at("body", default: [])
    return link(dest, collapse-punctuation(
      body,
      punctuation-in-quote: punctuation-in-quote,
    ))
  }

  // Flatten plain text to allow punctuation rules across boundaries
  let normalized = if _is-plain-text(content) {
    content-to-string(content)
  } else {
    content
  }

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

  // Rule 1b: Duplicate punctuation across closing quotes (keep first)
  show regex("[.。][\u{201D}\"][.。]"): it => it
    .text
    .clusters()
    .slice(0, 2)
    .join()
  show regex("[,，、][\u{201D}\"][,，、]"): it => it
    .text
    .clusters()
    .slice(0, 2)
    .join()
  show regex("[;；][\u{201D}\"][;；]"): it => it
    .text
    .clusters()
    .slice(0, 2)
    .join()
  show regex("[:：][\u{201D}\"][:：]"): it => it
    .text
    .clusters()
    .slice(0, 2)
    .join()
  show regex("[!！][\u{201D}\"][!！]"): it => it
    .text
    .clusters()
    .slice(0, 2)
    .join()
  show regex("[?？][\u{201D}\"][?？]"): it => it
    .text
    .clusters()
    .slice(0, 2)
    .join()

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

  // Absorption across closing quotes
  show regex("[!！][\u{201D}\"][:：]"): it => it
    .text
    .clusters()
    .slice(0, 2)
    .join()
  show regex("[?？][\u{201D}\"][:：]"): it => it
    .text
    .clusters()
    .slice(0, 2)
    .join()
  show regex("[;；][\u{201D}\"][:：]"): it => it
    .text
    .clusters()
    .slice(0, 2)
    .join()

  // punctuation-in-quote: move periods and commas inside closing quotes
  // Only applies when the locale has punctuation-in-quote="true" (e.g., en-US)
  // Pattern: closing quote followed by period or comma → swap them
  // Handles: " (right double quote)
  // Note: We handle this conditionally by wrapping in another layer
  if punctuation-in-quote {
    // If a question/exclamation mark is already inside the quote,
    // drop a trailing period after the closing quote.
    show regex("[?？][\u{201D}\"]\\."): it => it
      .text
      .clusters()
      .slice(0, 2)
      .join()
    show regex("[!！][\u{201D}\"]\\."): it => it
      .text
      .clusters()
      .slice(0, 2)
      .join()
    // Right double quote + period/comma → swap them
    // Collapse duplicate period/comma before swapping
    show regex("[.。][\u{201D}\"][.。]"): it => it
      .text
      .clusters()
      .slice(0, 2)
      .join()
    show regex("[,，、][\u{201D}\"][,，、]"): it => it
      .text
      .clusters()
      .slice(0, 2)
      .join()
    show "\u{201D}.": ".\u{201D}"
    show "\u{201D},": ",\u{201D}"
    // Straight double quote + period/comma → swap them
    show "\".": ".\""
    show "\",": ",\""
    normalized
  } else {
    normalized
  }
}

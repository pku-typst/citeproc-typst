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

#let _insert-punct-before-quote(text, punct) = {
  let clusters = text.clusters()
  if clusters.len() == 0 { return none }
  let last = clusters.last()
  if last == "\u{201D}" or last == "\"" {
    let base = clusters.slice(0, clusters.len() - 1).join()
    return base + punct + last
  }
  none
}

#let _move-punct-into-quoted(content, punct) = {
  if type(content) == array and content.len() > 0 {
    let last = content.last()
    let updated-last = _move-punct-into-quoted(last, punct)
    if updated-last != none {
      let updated = content.slice(0, content.len() - 1)
      updated.push(updated-last)
      return updated.join()
    }
  }

  if type(content) == str {
    return _insert-punct-before-quote(content, punct)
  }

  let func = content.func()
  let fields = content.fields()

  if "body" in fields and type(fields.body) == str {
    let updated = _insert-punct-before-quote(fields.body, punct)
    if updated != none {
      return func(..fields, body: updated)
    }
  }

  if "text" in fields and type(fields.text) == str {
    let updated = _insert-punct-before-quote(fields.text, punct)
    if updated != none {
      if func == text {
        return text(updated)
      }
      return func(..fields, body: updated)
    }
  }

  none
}

#let _literal-text(content) = {
  if type(content) == str { return content }
  let fields = content.fields()
  if "body" in fields and type(fields.body) == str { return fields.body }
  if "text" in fields and type(fields.text) == str { return fields.text }
  if "children" in fields and fields.children.len() > 0 {
    let first = fields.children.first()
    if type(first) == str { return first }
    let first-fields = first.fields()
    if "body" in first-fields and type(first-fields.body) == str {
      return first-fields.body
    }
    if "text" in first-fields and type(first-fields.text) == str {
      return first-fields.text
    }
  }
  none
}

#let _strip-leading-punct(text) = {
  let clusters = text.clusters()
  if clusters.len() == 0 { return text }
  let first = clusters.first()
  if first in (".", ",") {
    clusters.slice(1).join()
  } else {
    text
  }
}

#let _strip-leading-punct-content(content) = {
  if type(content) == str {
    return _strip-leading-punct(content)
  }

  let func = content.func()
  let fields = content.fields()

  if "body" in fields and type(fields.body) == str {
    let updated = _strip-leading-punct(fields.body)
    return func(..fields, body: updated)
  }

  if "text" in fields and type(fields.text) == str {
    let updated = _strip-leading-punct(fields.text)
    if func == text {
      return text(updated)
    }
    return func(..fields, body: updated)
  }

  if "children" in fields and fields.children.len() > 0 {
    let kids = fields.children
    let first = kids.first()
    let first-text = _literal-text(first)
    if first-text != none {
      let stripped = _strip-leading-punct(first-text)
      if stripped != first-text {
        let updated = (stripped,)
        for item in kids.slice(1) { updated.push(item) }
        return updated.join()
      }
    }
  }

  content
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

  if punctuation-in-quote and type(content) == array and content.len() >= 2 {
    let last-text = _literal-text(content.last())
    if last-text != none and last-text in (".", ",") {
      let punct = last-text
      let prev = content.at(content.len() - 2)
      let moved = _move-punct-into-quoted(prev, punct)
      if moved != none {
        let updated = content.slice(0, content.len() - 2)
        updated.push(moved)
        return updated.join()
      }
    }
  }

  if punctuation-in-quote and content != none and type(content) != str {
    let func = content.func()
    let fields = content.fields()
    if "children" in fields {
      let kids = fields.children
      if kids.len() >= 2 {
        let last-text = _literal-text(kids.last())
        if last-text != none and last-text in (".", ",") {
          let punct = last-text
          let prev = kids.at(kids.len() - 2)
          let moved = _move-punct-into-quoted(prev, punct)
          if moved != none {
            let updated = kids.slice(0, kids.len() - 2)
            updated.push(moved)
            return updated.join()
          }
        }
      }
      let updated = ()
      for item in kids {
        if updated.len() > 0 {
          let prev = updated.last()
          let curr-text = _literal-text(item)
          if curr-text != none {
            let clusters = curr-text.clusters()
            if clusters.len() > 0 and clusters.first() in (".", ",") {
              let punct = clusters.first()
              let moved-prev = _move-punct-into-quoted(prev, punct)
              if moved-prev != none {
                updated = updated.slice(0, updated.len() - 1)
                updated.push(moved-prev)
                let stripped = _strip-leading-punct-content(item)
                updated.push(stripped)
                continue
              }
            }
          }
        }
        updated.push(item)
      }
      if updated != kids {
        return updated.join()
      }
    }
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
    normalized
  } else {
    normalized
  }
}

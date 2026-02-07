// citrus - Punctuation Collapsing
//
// Implements CSL punctuation collapsing rules based on citeproc-js LtoR_MAP.

/// Get the punctuation-in-quote setting from a parsed CSL style
///
/// - style: Parsed CSL style
/// Returns: Boolean indicating whether punctuation should be moved inside quotes
#import "../parsing/locales/mod.typ": create-fallback-locale

#let get-punctuation-in-quote(style) = {
  // Check style.locale.options first (merged locale)
  let locale = style.at("locale", default: (:))
  let options = locale.at("options", default: (:))
  if "punctuation-in-quote" in options {
    return options.at("punctuation-in-quote", default: false)
  }
  // Fallback to the default locale options if missing
  let default-locale = style.at("default-locale", default: "en-US")
  let fallback = create-fallback-locale(default-locale)
  let fallback-options = fallback.at("options", default: (:))
  fallback-options.at("punctuation-in-quote", default: false)
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
  if type(content) == array { return content.all(_is-plain-text) }
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

#let _flatten-content(content) = {
  if content == none { return () }
  if type(content) == array {
    let flat = ()
    for item in content {
      for sub in _flatten-content(item) { flat.push(sub) }
    }
    return flat
  }
  if type(content) == str { return (content,) }
  let fields = content.fields()
  if "children" in fields {
    let flat = ()
    for child in fields.children {
      for sub in _flatten-content(child) { flat.push(sub) }
    }
    return flat
  }
  (content,)
}

#let _insert-punct-before-quote(text, punct) = {
  let clusters = text.clusters()
  if clusters.len() == 0 { return none }
  let last = clusters.last()
  if last == "\u{201D}" {
    if clusters.len() >= 2 and clusters.at(clusters.len() - 2) == "\u{2019}" {
      let base = clusters.slice(0, clusters.len() - 2).join()
      return base + punct + "\u{2019}\u{201D}"
    }
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

  if _is-plain-text(content) {
    let text = content-to-string(content)
    let updated = _insert-punct-before-quote(text, punct)
    if updated != none { return updated }
  }

  let func = content.func()
  let fields = content.fields()

  if "children" in fields and fields.children.len() > 0 {
    let kids = fields.children
    let updated-last = _move-punct-into-quoted(kids.last(), punct)
    if updated-last != none {
      let updated = kids.slice(0, kids.len() - 1)
      updated.push(updated-last)
      return updated.join()
    }
  }

  if "body" in fields and type(fields.body) == str {
    let updated = _insert-punct-before-quote(fields.body, punct)
    if updated != none {
      if func in (emph, strong, underline, smallcaps, super, sub) {
        return func(updated)
      }
      return func(..fields, body: updated)
    }
  }
  if "body" in fields and type(fields.body) != str {
    let updated-body = _move-punct-into-quoted(fields.body, punct)
    if updated-body != none {
      if func in (emph, strong, underline, smallcaps, super, sub) {
        return func(updated-body)
      }
      return func(..fields, body: updated-body)
    }
  }

  if "text" in fields and type(fields.text) == str {
    let updated = _insert-punct-before-quote(fields.text, punct)
    if updated != none {
      if func == text {
        return text(updated)
      }
      if func in (emph, strong, underline, smallcaps, super, sub) {
        return func(updated)
      }
      return func(..fields, body: updated)
    }
  }
  if "text" in fields and type(fields.text) != str {
    let updated-text = _move-punct-into-quoted(fields.text, punct)
    if updated-text != none {
      if func == text {
        return text(updated-text)
      }
      if func in (emph, strong, underline, smallcaps, super, sub) {
        return func(updated-text)
      }
      return func(..fields, body: updated-text)
    }
  }

  if "children" in fields and fields.children.len() > 0 {
    let kids = fields.children
    let last = kids.last()
    let updated-last = _move-punct-into-quoted(last, punct)
    if updated-last != none {
      let updated = kids.slice(0, kids.len() - 1)
      updated.push(updated-last)
      let rebuilt = updated.join()
      if func in (emph, strong, underline, smallcaps, super, sub) {
        return func(rebuilt)
      }
      return rebuilt
    }
  }

  none
}

#let _literal-text(content) = {
  if type(content) == array and content.len() > 0 {
    let first = content.first()
    if type(first) == str { return first }
    let first-fields = first.fields()
    if "body" in first-fields and type(first-fields.body) == str {
      return first-fields.body
    }
    if "text" in first-fields and type(first-fields.text) == str {
      return first-fields.text
    }
  }
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

#let _leading-punct(text) = {
  let clusters = text.clusters()
  for c in clusters {
    if c != " " and c != "\t" and c != "\n" {
      if c in (".", ",") { return c }
      return none
    }
  }
  none
}

#let _normalize-nested-double-quotes(text) = {
  if type(text) != str { return text }
  let clusters = text.clusters()
  let quote-count = 0
  for ch in clusters {
    if ch == "“" or ch == "”" or ch == "\"" { quote-count += 1 }
  }
  if quote-count < 4 { return text }
  let result = ""
  let level = 0
  for (i, ch) in clusters.enumerate() {
    if ch == "“" or ch == "\"" {
      let prev = if i > 0 { clusters.at(i - 1) } else { "" }
      let can-open = i == 0 or prev in (" ", "\t", "\n", "(", "[")
      if can-open {
        result += if level == 0 { "“" } else { "‘" }
        level += 1
      } else {
        level = calc.max(level - 1, 0)
        result += if level == 0 { "”" } else { "’" }
      }
    } else if ch == "”" {
      level = calc.max(level - 1, 0)
      result += if level == 0 { "”" } else { "’" }
    } else {
      result += ch
    }
  }
  result
}

#let _trailing-punct(text) = {
  let clusters = text.clusters()
  let idx = clusters.len() - 1
  while idx >= 0 {
    let c = clusters.at(idx)
    if c != " " and c != "\t" and c != "\n" {
      if c in (".", ",", ";", ":", "!", "?") { return c }
      return none
    }
    idx -= 1
  }
  none
}

#let _strip-leading-punct(text) = {
  let clusters = text.clusters()
  if clusters.len() == 0 { return text }
  let index = 0
  while (
    index < clusters.len()
      and (
        clusters.at(index) == " "
          or clusters.at(index) == "\t"
          or clusters.at(index) == "\n"
      )
  ) {
    index += 1
  }
  if index < clusters.len() and clusters.at(index) in (".", ",") {
    let prefix = clusters.slice(0, index).join()
    let rest = clusters.slice(index + 1).join()
    prefix + rest
  } else {
    text
  }
}

#let _strip-leading-punct-content(content) = {
  if type(content) == array and content.len() > 0 {
    let first = content.first()
    let first-text = _literal-text(first)
    if first-text != none {
      let stripped = _strip-leading-punct(first-text)
      if stripped != first-text {
        let updated = (stripped,)
        for item in content.slice(1) { updated.push(item) }
        return updated.join()
      }
    }
  }
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

  if punctuation-in-quote {
    let flat = _flatten-content(content)
    if flat.len() >= 2 {
      let updated = ()
      let changed = false
      for item in flat {
        if updated.len() > 0 {
          let prev = updated.last()
          let curr-text = _literal-text(item)
          if curr-text == none {
            curr-text = content-to-string(item)
          }
          let punct = if curr-text != none { _leading-punct(curr-text) } else {
            none
          }
          if punct != none {
            let moved-prev = _move-punct-into-quoted(prev, punct)
            if moved-prev != none {
              updated = updated.slice(0, updated.len() - 1)
              updated.push(moved-prev)
              let stripped = _strip-leading-punct-content(item)
              updated.push(stripped)
              changed = true
              continue
            }
            if _is-plain-text(prev) {
              let prev-str = content-to-string(prev)
              let updated-prev = _insert-punct-before-quote(prev-str, punct)
              if updated-prev != none {
                updated = updated.slice(0, updated.len() - 1)
                updated.push(updated-prev)
                let stripped = _strip-leading-punct-content(item)
                updated.push(stripped)
                changed = true
                continue
              }
            }
          }
        }
        updated.push(item)
      }
      if changed {
        return updated.join()
      }
    }

    if flat.len() > 0 {
      let updated = ()
      let changed = false
      for item in flat {
        if type(item) == str {
          let swapped = item.replace("\u{201D},", ",\u{201D}")
          swapped = swapped.replace("\u{2019}.\u{201D}", ".\u{2019}\u{201D}")
          swapped = swapped.replace(regex("(\\d),\\s*\\("), "$1 (")
          swapped = _normalize-nested-double-quotes(swapped)
          if swapped != item { changed = true }
          updated.push(swapped)
          continue
        }
        let fields = item.fields()
        if "body" in fields and type(fields.body) == str {
          let swapped = fields.body.replace("\u{201D},", ",\u{201D}")
          swapped = swapped.replace("\u{2019}.\u{201D}", ".\u{2019}\u{201D}")
          swapped = swapped.replace(regex("(\\d),\\s*\\("), "$1 (")
          let normalized = _normalize-nested-double-quotes(swapped)
          if normalized != fields.body { changed = true }
          if item.func() == text {
            updated.push(text(normalized))
          } else {
            updated.push(item.func()(..fields, body: normalized))
          }
          continue
        }
        if "text" in fields and type(fields.text) == str {
          let swapped = fields.text.replace("\u{201D},", ",\u{201D}")
          swapped = swapped.replace("\u{2019}.\u{201D}", ".\u{2019}\u{201D}")
          swapped = swapped.replace(regex("(\\d),\\s*\\("), "$1 (")
          let normalized = _normalize-nested-double-quotes(swapped)
          if normalized != fields.text { changed = true }
          if item.func() == text {
            updated.push(text(normalized))
          } else {
            updated.push(item.func()(..fields, text: normalized))
          }
          continue
        }
        updated.push(item)
      }
      if changed {
        return collapse-punctuation(
          updated.join(),
          punctuation-in-quote: punctuation-in-quote,
        )
      }
    }
  }

  // Collapse duplicate punctuation across content boundaries
  let flat = _flatten-content(content)
  if flat.len() >= 2 {
    let updated = ()
    let changed = false
    for i in range(flat.len()) {
      let item = flat.at(i)
      if updated.len() > 0 {
        let prev = updated.last()
        let prev-text = content-to-string(prev)
        let curr-text = _literal-text(item)
        if curr-text == none {
          curr-text = content-to-string(item)
        }
        let next-text = none
        if i + 1 < flat.len() {
          next-text = _literal-text(flat.at(i + 1))
          if next-text == none {
            next-text = content-to-string(flat.at(i + 1))
          }
        }
        if (
          prev-text != none
            and curr-text != none
            and prev-text.trim().ends-with("\u{2019}")
            and curr-text == "."
            and next-text != none
            and next-text.trim().starts-with("\u{201D}")
        ) {
          let updated-prev = prev-text.replace(regex("\u{2019}$"), ".\u{2019}")
          if updated-prev != prev-text {
            updated = updated.slice(0, updated.len() - 1)
            if type(prev) == str {
              updated.push(updated-prev)
            } else if prev.func() == text {
              let fields = prev.fields()
              if "body" in fields and type(fields.body) == str {
                let updated-body = fields.body.replace(
                  regex("\u{2019}$"),
                  ".\u{2019}",
                )
                updated.push(text(updated-body))
              } else if "text" in fields and type(fields.text) == str {
                let updated-text = fields.text.replace(
                  regex("\u{2019}$"),
                  ".\u{2019}",
                )
                updated.push(text(updated-text))
              } else {
                updated.push(prev)
              }
            } else {
              updated.push(prev)
            }
            changed = true
            continue
          }
        }
        if (
          prev-text != none
            and curr-text != none
            and prev-text.trim().ends-with("\u{2019}")
            and curr-text.starts-with(".\u{201D}")
        ) {
          let updated-prev = prev-text.replace(regex("\u{2019}$"), ".\u{2019}")
          if updated-prev != prev-text {
            updated = updated.slice(0, updated.len() - 1)
            if type(prev) == str {
              updated.push(updated-prev)
            } else if prev.func() == text {
              let fields = prev.fields()
              if "body" in fields and type(fields.body) == str {
                let updated-body = fields.body.replace(
                  regex("\u{2019}$"),
                  ".\u{2019}",
                )
                updated.push(text(updated-body))
              } else if "text" in fields and type(fields.text) == str {
                let updated-text = fields.text.replace(
                  regex("\u{2019}$"),
                  ".\u{2019}",
                )
                updated.push(text(updated-text))
              } else {
                updated.push(prev)
              }
            } else {
              updated.push(prev)
            }
            updated.push(_strip-leading-punct-content(item))
            changed = true
            continue
          }
        }
        if (
          prev-text != none
            and curr-text != none
            and prev-text.trim().ends-with(",")
            and curr-text.trim().starts-with("(")
        ) {
          let cleaned = prev-text.replace(regex(",\\s*$"), " ")
          if cleaned != prev-text {
            updated = updated.slice(0, updated.len() - 1)
            if type(prev) == str {
              updated.push(cleaned)
            } else if prev.func() == text {
              let fields = prev.fields()
              if "body" in fields and type(fields.body) == str {
                let updated-body = fields.body.replace(regex(",\\s*$"), " ")
                updated.push(text(updated-body))
              } else if "text" in fields and type(fields.text) == str {
                let updated-text = fields.text.replace(regex(",\\s*$"), " ")
                updated.push(text(updated-text))
              } else {
                updated.push(prev)
              }
            } else {
              updated.push(prev)
            }
            updated.push(item)
            changed = true
            continue
          }
        }
        let prev-punct = if prev-text != none {
          _trailing-punct(prev-text)
        } else {
          none
        }
        let curr-punct = if curr-text != none {
          _leading-punct(curr-text)
        } else {
          none
        }
        if prev-punct != none and curr-punct == prev-punct {
          let prev-trim = prev-text.trim()
          let prev-only-punct = (
            prev-trim.len() == 1 and prev-trim in (".", ",", ";", ":", "!", "?")
          )
          let curr-delim = false
          if curr-text != none {
            let trimmed = curr-text.trim()
            if trimmed.len() > 1 {
              let rest = trimmed.slice(1).trim()
              if rest.starts-with("–") or rest.starts-with("-") {
                curr-delim = true
              }
            }
          }
          let prev-has-trailing-space = (
            prev-text.ends-with(" ")
              or prev-text.ends-with("\t")
              or prev-text.ends-with("\n")
          )
          if (
            (not prev-only-punct or curr-delim) and not prev-has-trailing-space
          ) {
            updated.push(_strip-leading-punct-content(item))
            changed = true
            continue
          }
        }
      }
      updated.push(item)
    }
    if changed {
      return updated.join()
    }
  }

  if (
    punctuation-in-quote
      and content != none
      and type(content) != str
      and type(content) != array
  ) {
    let func = content.func()
    let fields = content.fields()
    if "children" in fields {
      let kids = fields.children
      if kids.len() >= 2 {
        let last-text = _literal-text(kids.last())
        if last-text == none {
          last-text = content-to-string(kids.last())
        }
        let punct = if last-text != none { _leading-punct(last-text) } else {
          none
        }
        if punct != none {
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
    show regex("[?？]\u{201D}\\."): it => it.text.clusters().slice(0, 2).join()
    show regex("[!！]\u{201D}\\."): it => it.text.clusters().slice(0, 2).join()
    // Right double quote + period/comma → swap them
    // Collapse duplicate period/comma before swapping
    show regex("[.。]\u{201D}[.。]"): it => it
      .text
      .clusters()
      .slice(0, 2)
      .join()
    show regex("[,，、]\u{201D}[,，、]"): it => it
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

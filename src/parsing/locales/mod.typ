// citrus - Locale Management
//
// Centralized language detection and built-in locale data.
// Each locale is defined in its own file for maintainability.

// =============================================================================
// Import All Locales
// =============================================================================

#import "en-US.typ": locale as _en-US
#import "zh-CN.typ": locale as _zh-CN
#import "zh-TW.typ": locale as _zh-TW
#import "de-DE.typ": locale as _de-DE
#import "fr-FR.typ": locale as _fr-FR
#import "es-ES.typ": locale as _es-ES
#import "ja-JP.typ": locale as _ja-JP
#import "ko-KR.typ": locale as _ko-KR
#import "pt-BR.typ": locale as _pt-BR
#import "ru-RU.typ": locale as _ru-RU
#import "ar.typ": locale as _ar
#import "tr-TR.typ": locale as _tr-TR
#import "it-IT.typ": locale as _it-IT
#import "nl-NL.typ": locale as _nl-NL
#import "pl-PL.typ": locale as _pl-PL
#import "cs-CZ.typ": locale as _cs-CZ

// =============================================================================
// Built-in Locale Registry
// =============================================================================

#let _builtin-locales = (
  "en-US": _en-US,
  "zh-CN": _zh-CN,
  "zh-TW": _zh-TW,
  "de-DE": _de-DE,
  "fr-FR": _fr-FR,
  "es-ES": _es-ES,
  "ja-JP": _ja-JP,
  "ko-KR": _ko-KR,
  "pt-BR": _pt-BR,
  "ru-RU": _ru-RU,
  "ar": _ar,
  "tr-TR": _tr-TR,
  "it-IT": _it-IT,
  "nl-NL": _nl-NL,
  "pl-PL": _pl-PL,
  "cs-CZ": _cs-CZ,
)

// =============================================================================
// Language Detection
// =============================================================================

/// Check if text contains CJK (Chinese/Japanese/Korean) characters
#let is-cjk-text(text) = {
  if text == none or text == "" { return false }
  let s = if type(text) == str { text } else { str(text) }

  s
    .codepoints()
    .any(c => {
      let code = c.to-unicode()
      // CJK Unified Ideographs (0x4E00-0x9FFF)
      // CJK Extension A (0x3400-0x4DBF)
      (code >= 0x4E00 and code <= 0x9FFF) or (code >= 0x3400 and code <= 0x4DBF)
    })
}

/// Check if a name dict contains CJK characters
#let is-cjk-name(name) = {
  let family = name.at("family", default: "")
  let given = name.at("given", default: "")
  is-cjk-text(family + given)
}

// Language name to code mappings
#let _language-name-map = (
  "chinese": "zh",
  "english": "en",
  "german": "de",
  "french": "fr",
  "spanish": "es",
  "japanese": "ja",
  "korean": "ko",
  "portuguese": "pt",
  "russian": "ru",
)

// Language code prefixes for detection
#let _language-code-prefixes = (
  "zh",
  "en",
  "de",
  "fr",
  "es",
  "ja",
  "ko",
  "pt",
  "ru",
  "ar",
  "tr",
  "it",
  "nl",
  "pl",
  "cs",
)

/// Detect language from context or fields
#let detect-language(ctx-or-fields) = {
  let fields = if (
    type(ctx-or-fields) == dictionary and "fields" in ctx-or-fields
  ) {
    ctx-or-fields.fields
  } else if type(ctx-or-fields) == dictionary {
    ctx-or-fields
  } else {
    (:)
  }

  let lang = fields.at("language", default: "")
  if lang != "" {
    let lower-lang = lower(lang)

    for (name, code) in _language-name-map.pairs() {
      if lower-lang.contains(name) { return code }
    }

    for prefix in _language-code-prefixes {
      if lower-lang.starts-with(prefix) { return prefix }
    }

    return lower-lang.slice(0, calc.min(2, lower-lang.len()))
  }

  let title = fields.at("title", default: "")
  if is-cjk-text(title) { return "zh" }

  "en"
}

/// Check if entry is Chinese
#let is-chinese-entry(ctx) = { detect-language(ctx) == "zh" }

/// Check if entry is English
#let is-english-entry(ctx) = { detect-language(ctx) == "en" }

// =============================================================================
// Locale Access
// =============================================================================

/// Language family mappings for fallback
#let _language-family-map = (
  "zh": "zh-CN",
  "en": "en-US",
  "de": "de-DE",
  "fr": "fr-FR",
  "es": "es-ES",
  "ja": "ja-JP",
  "ko": "ko-KR",
  "pt": "pt-BR",
  "ru": "ru-RU",
  "ar": "ar",
  "tr": "tr-TR",
  "it": "it-IT",
  "nl": "nl-NL",
  "pl": "pl-PL",
  "cs": "cs-CZ",
)

/// Get a built-in locale by language code
#let get-builtin-locale(lang) = {
  let locale = _builtin-locales.at(lang, default: none)
  if locale != none { return locale }

  let prefix = if lang.len() >= 2 { lower(lang.slice(0, 2)) } else {
    lower(lang)
  }
  let target = _language-family-map.at(prefix, default: "en-US")
  _builtin-locales.at(target)
}

/// Create a fallback locale for a language code
#let create-fallback-locale(lang) = {
  let builtin = get-builtin-locale(lang)
  (
    lang: lang,
    terms: builtin.terms,
    dates: builtin.dates,
    options: builtin.options,
  )
}

// =============================================================================
// CSL-M Locale Matching
// =============================================================================

/// Check if entry language matches a locale specification (CSL-M extension)
#let locale-matches(entry-lang, locale-spec) = {
  if locale-spec == none or locale-spec == "" { return true }

  let entry-prefix = if entry-lang.len() >= 2 {
    lower(entry-lang.slice(0, 2))
  } else {
    lower(entry-lang)
  }

  let locales = locale-spec.split(" ").map(s => s.trim()).filter(s => s != "")

  for locale in locales {
    let locale-prefix = if locale.len() >= 2 {
      lower(locale.slice(0, 2))
    } else {
      lower(locale)
    }

    if entry-prefix == locale-prefix { return true }
    if lower(entry-lang) == lower(locale) { return true }
  }

  false
}

/// Get the fallback chain for a language code (CSL-M extension)
#let get-locale-fallback-chain(lang) = {
  let chain = ()

  if lang != "" and lang in _builtin-locales {
    chain.push(lang)
  }

  let prefix = if lang.len() >= 2 { lower(lang.slice(0, 2)) } else {
    lower(lang)
  }
  let family-default = _language-family-map.at(prefix, default: none)

  if family-default != none and family-default not in chain {
    chain.push(family-default)
  }

  if "en-US" not in chain {
    chain.push("en-US")
  }

  chain
}

// =============================================================================
// Term Lookup
// =============================================================================

/// Look up a term from locale
///
/// CSL term lookup follows this fallback chain:
/// 1. Exact form match (e.g., "reviewed-author-verb-short")
/// 2. Form base fallback (e.g., "verb-short" -> "verb", "short" -> "long")
/// 3. Base term name (e.g., "reviewed-author")
#let lookup-term(ctx, name, form: "long", plural: false) = {
  let terms = ctx.locale.terms

  // Build list of keys to try in order
  let keys-to-try = ()

  if form == "long" {
    keys-to-try = (name,)
  } else if form == "verb-short" {
    // verb-short -> verb -> base
    keys-to-try = (name + "-verb-short", name + "-verb", name)
  } else if form == "short" {
    // short -> long (base)
    keys-to-try = (name + "-short", name)
  } else if form == "verb" {
    // verb -> base
    keys-to-try = (name + "-verb", name)
  } else if form == "symbol" {
    // symbol -> short -> base
    keys-to-try = (name + "-symbol", name + "-short", name)
  } else {
    // Generic fallback
    keys-to-try = (name + "-" + form, name)
  }

  // Try each key in order
  let term-value = none
  for key in keys-to-try {
    let val = terms.at(key, default: none)
    if val != none {
      term-value = val
      break
    }
  }

  // If still none, return empty string
  if term-value == none {
    return ""
  }

  // Handle singular/plural dictionary format
  if type(term-value) == dictionary {
    if plural {
      term-value.at("multiple", default: term-value.at("single", default: ""))
    } else {
      term-value.at("single", default: "")
    }
  } else {
    term-value
  }
}

// =============================================================================
// Quote Character Lookup
// =============================================================================

/// Get quote characters for a language
#let get-quote-chars(lang) = {
  let locale = get-builtin-locale(lang)
  let terms = locale.terms

  let default-quotes = (
    "open-quote": "\u{201C}",
    "close-quote": "\u{201D}",
    "open-inner-quote": "\u{2018}",
    "close-inner-quote": "\u{2019}",
  )

  (
    "open-quote": terms.at("open-quote", default: default-quotes.open-quote),
    "close-quote": terms.at("close-quote", default: default-quotes.close-quote),
    "open-inner-quote": terms.at(
      "open-inner-quote",
      default: default-quotes.open-inner-quote,
    ),
    "close-inner-quote": terms.at(
      "close-inner-quote",
      default: default-quotes.close-inner-quote,
    ),
  )
}

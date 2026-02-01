// citrus - Number and Label Handlers
//
// Handles <number> and <label> CSL elements.

#import "../core/mod.typ": finalize, is-empty, safe-int, zero-pad
#import "../data/variables.typ": get-variable
#import "../parsing/mod.typ": lookup-term

// Pattern to find all numbers in a string
#let _number-pattern = regex("\\d+")

/// Check if a value string represents plural content (multiple numbers)
///
/// CSL spec: Content is considered plural when it contains multiple numbers
/// (e.g. "pages 1-3", "volumes 2 & 4"), or for number-of-* variables when > 1.
/// Non-numeric content like "Michaelson-Morely" is NOT plural.
#let _is-plural-value(val-str) = {
  if val-str == "" { return false }

  // Find all numbers in the string
  let matches = val-str.matches(_number-pattern)

  // Plural if there are 2+ distinct number occurrences
  // OR if there's a range separator between numbers
  if matches.len() >= 2 {
    true
  } else if matches.len() == 1 {
    // Single number - check if there's a range indicator after it
    // that would imply a range (like roman numerals: "i-ix")
    let has-range-sep = (
      val-str.contains("–")
        or val-str.contains("—")
        or (
          val-str.contains("-")
            and val-str.match(regex("\\d.*-.*[ivxlcdmIVXLCDM]")) != none
        )
        or (
          val-str.contains("-")
            and val-str.match(regex("[ivxlcdmIVXLCDM].*-")) != none
        )
    )
    has-range-sep
  } else {
    // No Arabic numbers - check for Roman numeral ranges
    let lower = val-str.replace(" ", "")
    let has-roman-range = (
      lower.match(
        regex(
          "[ivxlcdm]+[\\-–—][ivxlcdm]+",
        ),
      )
        != none
    )
    has-roman-range
  }
}

/// Get ordinal suffix for a number according to CSL spec
///
/// CSL ordinal priority:
/// 1. ordinal-10 through ordinal-99: last-two-digits matching (higher priority)
/// 2. ordinal-00 through ordinal-09: last-digit matching
/// 3. ordinal: generic fallback
///
/// Match modes:
/// - whole-number: exact match
/// - last-two-digits: match last two digits (default for 10-99)
/// - last-digit: match last digit (default for 00-09)
///
/// - num: The number to get ordinal for
/// - ctx: Context with locale terms
/// - gender-form: Optional gender form ("masculine" or "feminine")
/// Returns: Ordinal suffix string
#let _get-ordinal-suffix(num, ctx, gender-form: none) = {
  let abs-num = calc.abs(num)
  let last-two = calc.rem(abs-num, 100)
  let last-one = calc.rem(abs-num, 10)

  // Try ordinal-10 through ordinal-99 first (last-two-digits matching by default)
  if last-two >= 10 {
    let key = "ordinal-" + zero-pad(last-two, 2)
    let suffix = lookup-term(ctx, key, form: "long", plural: false)
    if suffix != "" and suffix != key {
      return suffix
    }
  }

  // Try ordinal-00 through ordinal-09 (last-digit matching by default)
  let single-key = "ordinal-" + zero-pad(last-one, 2)
  let single-suffix = lookup-term(ctx, single-key, form: "long", plural: false)
  if single-suffix != "" and single-suffix != single-key {
    return single-suffix
  }

  // Fallback to generic ordinal term
  lookup-term(ctx, "ordinal", form: "long", plural: false)
}

/// Handle <number> element
#let handle-number(node, ctx, interpret) = {
  let attrs = node.at("attrs", default: (:))
  let var-name = attrs.at("variable", default: "")
  let val = get-variable(ctx, var-name)

  if not is-empty(val) {
    let form = attrs.at("form", default: "numeric")
    let num = safe-int(val)

    let result = if form == "ordinal" {
      if num != none {
        let suffix = _get-ordinal-suffix(num, ctx)
        str(num) + suffix
      } else { val }
    } else if form == "long-ordinal" {
      if num != none and num >= 1 and num <= 10 {
        let long-ordinal = lookup-term(
          ctx,
          "long-ordinal-" + zero-pad(num, 2),
          form: "long",
          plural: false,
        )
        // Fall back to ordinal if long-ordinal not defined
        if long-ordinal == "" or long-ordinal.starts-with("long-ordinal-") {
          str(num) + _get-ordinal-suffix(num, ctx)
        } else {
          long-ordinal
        }
      } else if num != none {
        // CSL spec: long-ordinal falls back to ordinal for numbers > 10
        str(num) + _get-ordinal-suffix(num, ctx)
      } else { val }
    } else if form == "roman" {
      if num != none and num > 0 {
        // Use Typst's built-in numbering for roman numerals
        numbering("i", num)
      } else { val }
    } else {
      // numeric (default)
      val
    }

    finalize(result, attrs)
  } else { [] }
}

// Known locator term names for embedded label detection
#let _locator-terms = (
  "page",
  "volume",
  "chapter",
  "section",
  "paragraph",
  "folio",
  "opus",
  "line",
  "verse",
  "figure",
  "column",
  "note",
  "number",
  "part",
  "sub verbo",
  "issue",
)

/// Check if locator value starts with an embedded label (from current locale)
#let _has-embedded-label(val-str, ctx, form) = {
  if val-str == "" { return false }
  let lower-val = lower(val-str)

  // Check each locator term in both singular and plural forms
  for term-name in _locator-terms {
    // Get term from locale
    let term-long = lookup-term(ctx, term-name, form: "long", plural: false)
    let term-long-pl = lookup-term(ctx, term-name, form: "long", plural: true)
    let term-short = lookup-term(ctx, term-name, form: "short", plural: false)
    let term-short-pl = lookup-term(ctx, term-name, form: "short", plural: true)

    for term in (term-long, term-long-pl, term-short, term-short-pl) {
      if term != "" and lower-val.starts-with(lower(term)) {
        return true
      }
    }
  }
  false
}

/// Handle <label> element
#let handle-label(node, ctx, interpret) = {
  let attrs = node.at("attrs", default: (:))
  let var-name = attrs.at("variable", default: "")
  let form = attrs.at("form", default: "long")

  // Only render label if variable has value
  let val = get-variable(ctx, var-name)
  if is-empty(val) {
    []
  } else {
    let val-str = if type(val) == str { val } else { "" }

    // For locator: skip label if value already has embedded label
    // e.g., locator="vol. 1, fol. 186" already contains "vol." label
    if var-name == "locator" and _has-embedded-label(val-str, ctx, form) {
      return []
    }

    // Determine plurality based on value content
    // CSL spec: Content is plural when it contains multiple numbers
    // (e.g. "pages 1-3", "volumes 2 & 4")
    // Non-numeric content like "Michaelson-Morely" is NOT plural
    // Special case: number-of-* variables are plural when value > 1
    let plural = if var-name.starts-with("number-of-") {
      let num = safe-int(val-str)
      num != none and num > 1
    } else {
      _is-plural-value(val-str)
    }

    // CSL spec: for locator variable, use locator-label to determine the term
    // e.g., locator-label="page" → lookup term "page" → "p." or "pp."
    let term-name = if var-name == "locator" {
      ctx.at("locator-label", default: "page")
    } else {
      var-name
    }

    let result = lookup-term(ctx, term-name, form: form, plural: plural)
    finalize(result, attrs)
  }
}

// citrus - Range Formatting Module
//
// Handles page and year range formatting according to CSL options:
// - page-range-format: expanded, minimal, minimal-two, chicago, chicago-15, chicago-16
// - year-range-format: same options

// =============================================================================
// Module-level regex patterns (avoid recompilation)
// =============================================================================

// Pattern for splitting ranges on dash or en-dash (with optional surrounding spaces)
#let _range-split-pattern = regex("\\s*[\\-–\\u2013]\\s*")

// Pattern for detecting digits
#let _digit-pattern = regex("[0-9]")

// =============================================================================
// Range Delimiter
// =============================================================================

/// Get the range delimiter from locale or use default
///
/// - ctx: Context with locale
/// - range-type: "page" or "year"
/// Returns: Delimiter string
#let get-range-delimiter(ctx, range-type: "page") = {
  if ctx == none { return "–" }

  let locale = ctx.at("locale", default: none)
  if locale == none { return "–" }

  let terms = locale.at("terms", default: (:))

  // Try specific range-delimiter term (e.g., "page-range-delimiter")
  let term-name = range-type + "-range-delimiter"
  let delimiter = terms.at(term-name, default: none)
  if delimiter != none and delimiter != "" {
    return delimiter
  }

  // CSL 1.0.1: For French and Portuguese, default to hyphen (not en-dash)
  // citeproc-js uses non-breaking hyphen U+2011 for fr locales
  let lang = locale.at("lang", default: "")
  if type(lang) == str and lang.len() >= 2 {
    let lang-prefix = lower(lang.slice(0, 2))
    if lang-prefix in ("fr", "pt") {
      return "-"
    }
  }

  // Default to en-dash
  "–"
}

// =============================================================================
// Range Parsing
// =============================================================================

/// Parse a range string into start and end parts
///
/// - range-str: String like "123-456" or "123–456"
/// Returns: (start, end) tuple or none if not a range
#let parse-range(range-str) = {
  if range-str == none or range-str == "" { return none }

  let str = str(range-str)

  // Match patterns like "123-456", "123–456", "A123-A456", "123a-123b"
  let parts = str.split(_range-split-pattern)

  if parts.len() == 2 {
    let start = parts.at(0).trim()
    let end = parts.at(1).trim()
    if start != "" and end != "" {
      return (start: start, end: end)
    }
  }

  none
}

/// Expand a shortened range end to its full form
///
/// Examples:
/// - expand-range-end("100", "4") -> "104"
/// - expand-range-end("600", "13") -> "613"
/// - expand-range-end("1100", "23") -> "1123"
/// - expand-range-end("100", "104") -> "104" (already full)
///
/// - start: Full start number string
/// - end: Possibly shortened end number string
/// Returns: Expanded end number string
#let expand-range-end(start, end) = {
  // If end is already same length or longer, no expansion needed
  if end.len() >= start.len() {
    return end
  }

  // Simple case: both are pure digits
  // This handles common cases like "100-4" -> "100-104"
  let s-is-digits = (
    start.match(_digit-pattern) != none
      and start.clusters().all(c => c.match(_digit-pattern) != none)
  )
  let e-is-digits = (
    end.match(_digit-pattern) != none
      and end.clusters().all(c => c.match(_digit-pattern) != none)
  )

  if s-is-digits and e-is-digits {
    // Simple expansion: prepend prefix digits from start
    let prefix-len = start.len() - end.len()
    return start.slice(0, prefix-len) + end
  }

  // For more complex cases with prefixes/suffixes, return as-is for now
  // (will be handled by parse-page-parts after it's defined)
  end
}

// Pattern for detecting Roman numerals
#let _roman-pattern = regex("^[ivxlcdmIVXLCDM]+$")

/// Check if a string is numeric according to CSL rules
///
/// Content is considered numeric if it contains at least one digit
/// OR is a valid Roman numeral.
/// Numbers may have prefixes and suffixes ("D2", "2b", "L2d").
///
/// - s: String to check
/// Returns: true if numeric
#let is-numeric-string(s) = {
  if s == none or s == "" { return false }
  let str = str(s).trim()
  // Contains Arabic digit OR is pure Roman numeral
  str.match(_digit-pattern) != none or str.match(_roman-pattern) != none
}

/// Extract numeric part and prefix/suffix from a page number
///
/// - page-str: String like "123", "A123", "123a"
/// Returns: (prefix, number, suffix) tuple
#let parse-page-parts(page-str) = {
  if page-str == "" { return ("", "", "") }

  let str = page-str.trim()

  // Match prefix (letters before digits), number, suffix (letters after digits)
  let prefix = ""
  let number = ""
  let suffix = ""

  let in-number = false
  let after-number = false

  for char in str.clusters() {
    let is-digit = char.match(_digit-pattern) != none

    if is-digit {
      if after-number {
        // This shouldn't happen in valid page numbers
        suffix += char
      } else {
        number += char
        in-number = true
      }
    } else {
      if in-number {
        after-number = true
        suffix += char
      } else {
        prefix += char
      }
    }
  }

  (prefix, number, suffix)
}

// =============================================================================
// Range Formatting
// =============================================================================

/// Format a range with expanded format (full numbers on both sides)
///
/// - start: Start of range
/// - end: End of range
/// - delimiter: Range delimiter
/// Returns: Formatted string
#let format-range-expanded(start, end, delimiter) = {
  start + delimiter + end
}

/// Format a range with minimal format (remove common leading digits)
///
/// - start: Start of range
/// - end: End of range
/// - delimiter: Range delimiter
/// - min-chars: Minimum characters to keep in end (default 1)
/// Returns: Formatted string
#let format-range-minimal(start, end, delimiter, min-chars: 1) = {
  let (s-prefix, s-num, s-suffix) = parse-page-parts(start)
  let (e-prefix, e-num, e-suffix) = parse-page-parts(end)

  // If prefixes differ, use expanded format
  if s-prefix != e-prefix {
    return format-range-expanded(start, end, delimiter)
  }

  // If numbers are same length, try to minimize
  if s-num.len() == e-num.len() and s-num.len() > 0 {
    let s-chars = s-num.clusters()
    let e-chars = e-num.clusters()

    // Find how many leading digits match
    let matching = 0
    for i in range(s-chars.len()) {
      if s-chars.at(i) == e-chars.at(i) {
        matching += 1
      } else {
        break
      }
    }

    // Keep at least min-chars in the end
    let keep = calc.max(e-chars.len() - matching, min-chars)
    let minimized-end = e-chars.slice(e-chars.len() - keep).join("")

    return (
      s-prefix
        + s-num
        + s-suffix
        + delimiter
        + e-prefix
        + minimized-end
        + e-suffix
    )
  }

  format-range-expanded(start, end, delimiter)
}

/// Format a range with Chicago 15th edition style
///
/// Chicago 15th (from CMOS 9.61):
/// - Numbers < 100: use all digits (4-11, 81-83)
/// - 100 or multiples of 100: use all digits (100-105, 1200-1213)
/// - x01-x09 (ends in 01-09): use changed part only (101-4, 303-7, 1002-6)
/// - x10-x99: use two digits minimum (253-64, 1077-79, 1597-600)
///
/// - start: Start of range
/// - end: End of range
/// - delimiter: Range delimiter
/// Returns: Formatted string
#let format-range-chicago15(start, end, delimiter) = {
  let (s-prefix, s-num, s-suffix) = parse-page-parts(start)
  let (e-prefix, e-num, e-suffix) = parse-page-parts(end)

  if s-prefix != e-prefix or s-num == "" or e-num == "" {
    return format-range-expanded(start, end, delimiter)
  }

  let s-int = int(s-num)
  let e-int = int(e-num)

  // Rule 1: Numbers < 100 - use all digits
  if s-int < 100 {
    return s-prefix + s-num + s-suffix + delimiter + e-prefix + e-num + e-suffix
  }

  // Rule 2: 100 or multiples of 100 - use all digits
  if calc.rem(s-int, 100) == 0 {
    return s-prefix + s-num + s-suffix + delimiter + e-prefix + e-num + e-suffix
  }

  let s-str = str(s-int)
  let e-str = str(e-int)

  // If different lengths, use expanded
  if s-str.len() != e-str.len() {
    return format-range-expanded(start, end, delimiter)
  }

  // Rule 3: x01-x09 - use changed part only (can be single digit)
  // BUT: only if end is also in single-digit range (x01-x09)
  let s-last-two = calc.rem(s-int, 100)
  let e-last-two = calc.rem(e-int, 100)
  if (
    s-last-two >= 1 and s-last-two <= 9 and e-last-two >= 1 and e-last-two <= 9
  ) {
    // Both start and end are in x01-x09 range, just show the changed digit
    let minimized-end = str(calc.rem(e-int, 10))
    return (
      s-prefix
        + s-num
        + s-suffix
        + delimiter
        + e-prefix
        + minimized-end
        + e-suffix
    )
  }

  // Rule 4: x10-x99 - use two digits minimum, more if needed
  // Find first differing position from left
  let diff-pos = s-str.len()
  for i in range(s-str.len()) {
    if s-str.at(i) != e-str.at(i) {
      diff-pos = i
      break
    }
  }

  // Number of digits to keep from end
  let keep-digits = s-str.len() - diff-pos

  // Minimum 2 digits
  if keep-digits < 2 {
    keep-digits = 2
  }

  // Extract the abbreviated end
  let minimized-end = e-str.slice(e-str.len() - keep-digits)

  s-prefix + s-num + s-suffix + delimiter + e-prefix + minimized-end + e-suffix
}

/// Format a range with Chicago 16th edition style
///
/// Chicago 16th: Similar to 15th but slightly different rules
/// Uses changed part only, with minimum of 2 digits for numbers > 100
///
/// - start: Start of range
/// - end: End of range
/// - delimiter: Range delimiter
/// Returns: Formatted string
#let format-range-chicago16(start, end, delimiter) = {
  let (s-prefix, s-num, s-suffix) = parse-page-parts(start)
  let (e-prefix, e-num, e-suffix) = parse-page-parts(end)

  if s-prefix != e-prefix or s-num == "" or e-num == "" {
    return format-range-expanded(start, end, delimiter)
  }

  let s-int = int(s-num)
  let e-int = int(e-num)

  let minimized-end = if s-int > 100 and calc.rem(s-int, 100) != 0 {
    // Find the divisor where they differ
    let result = e-num
    for i in range(2, e-num.len()) {
      let divisor = calc.pow(10, i)
      if calc.floor(s-int / divisor) == calc.floor(e-int / divisor) {
        result = str(calc.rem(e-int, divisor))
        break
      }
    }
    result
  } else {
    e-num
  }

  s-prefix + s-num + s-suffix + delimiter + e-prefix + minimized-end + e-suffix
}

// =============================================================================
// Main API
// =============================================================================

/// Replace ampersand and comma with localized terms
///
/// CSL spec: "&" in locators should use the "and" term (symbol form)
/// - s: String to process
/// - ctx: Context for locale lookup
/// Returns: String with replacements
#let localize-separators(s, ctx) = {
  if ctx == none { return s }

  // Import lookup-term to get localized terms
  import "../parsing/mod.typ": lookup-term

  let result = s

  // Replace "&" with localized "and" term (symbol form)
  if result.contains("&") {
    let and-term = lookup-term(ctx, "and", form: "symbol", plural: false)
    if and-term != none and and-term != "" {
      result = result.replace("&", and-term)
    }
  }

  result
}

/// Format a page range according to CSL page-range-format
///
/// - page-str: Page string (may be a range like "123-456")
/// - format: "expanded", "minimal", "minimal-two", "chicago", "chicago-15", "chicago-16"
/// - ctx: Context for locale lookup
/// Returns: Formatted string
#let format-page-range(page-str, format: "expanded", ctx: none) = {
  if page-str == none or page-str == "" { return page-str }

  let delimiter = get-range-delimiter(ctx, range-type: "page")
  let range = parse-range(page-str)

  if range == none {
    // Not a range, apply separator localization and return
    return localize-separators(str(page-str), ctx)
  }

  let start = range.start
  let end-raw = range.end

  // Only process as numeric range if both parts contain digits
  // Non-numeric content like "Michaelson-Morely" should be returned as-is
  if not is-numeric-string(start) or not is-numeric-string(end-raw) {
    // Not a numeric range, return original string unchanged
    return str(page-str)
  }

  // Expand shortened end (e.g., "100-4" -> "100-104")
  // This is required before applying any range format
  let end = expand-range-end(start, end-raw)

  if format == "expanded" or format == none {
    format-range-expanded(start, end, delimiter)
  } else if format == "minimal" {
    format-range-minimal(start, end, delimiter, min-chars: 1)
  } else if format == "minimal-two" {
    format-range-minimal(start, end, delimiter, min-chars: 2)
  } else if format == "chicago" or format == "chicago-15" {
    format-range-chicago15(start, end, delimiter)
  } else if format == "chicago-16" {
    format-range-chicago16(start, end, delimiter)
  } else {
    // Unknown format, use expanded
    format-range-expanded(start, end, delimiter)
  }
}

/// Format a year range according to CSL year-range-format
///
/// - year-str: Year string (may be a range like "2020-2021")
/// - format: Same options as page-range-format
/// - ctx: Context for locale lookup
/// Returns: Formatted string
#let format-year-range(year-str, format: "expanded", ctx: none) = {
  if year-str == none or year-str == "" { return year-str }

  let delimiter = get-range-delimiter(ctx, range-type: "year")
  let range = parse-range(year-str)

  if range == none {
    return str(year-str).replace("-", delimiter)
  }

  let start = range.start
  let end = range.end

  // Year ranges typically use minimal-two for academic styles
  if format == "expanded" or format == none {
    format-range-expanded(start, end, delimiter)
  } else if format == "minimal" {
    format-range-minimal(start, end, delimiter, min-chars: 1)
  } else if format == "minimal-two" {
    format-range-minimal(start, end, delimiter, min-chars: 2)
  } else if (
    format == "chicago" or format == "chicago-15" or format == "chicago-16"
  ) {
    // Chicago style for years typically keeps last two digits
    format-range-minimal(start, end, delimiter, min-chars: 2)
  } else {
    format-range-expanded(start, end, delimiter)
  }
}

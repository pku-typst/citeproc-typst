// citrus - Date Formatting
//
// Uses Typst's native datetime for formatting

#import "../core/mod.typ": zero-pad
#import "../parsing/mod.typ": lookup-term

// =============================================================================
// Module-level constants (avoid recreating on each call)
// =============================================================================

// Date parsing regex patterns
#let _iso-date-pattern = regex("^(\\d{4})[-/](\\d{1,2})(?:[-/](\\d{1,2}))?$")
#let _year-only-pattern = regex("^(\\d{4})$")
#let _text-date-pattern = regex(
  "^([A-Za-z]+)\\s+(?:(\\d{1,2}),?\\s+)?(\\d{4})$",
)
#let _any-year-pattern = regex("(\\d{4})")
#let _full-iso-pattern = regex("\\d{4}-\\d{2}-\\d{2}")

// Month name to number mapping
#let _month-map = (
  "january": 1,
  "february": 2,
  "march": 3,
  "april": 4,
  "may": 5,
  "june": 6,
  "july": 7,
  "august": 8,
  "september": 9,
  "october": 10,
  "november": 11,
  "december": 12,
  "jan": 1,
  "feb": 2,
  "mar": 3,
  "apr": 4,
  "jun": 6,
  "jul": 7,
  "aug": 8,
  "sep": 9,
  "oct": 10,
  "nov": 11,
  "dec": 12,
)

/// Get ordinal suffix for a day number using locale terms
///
/// Uses CSL ordinal term priority:
/// 1. ordinal-10 through ordinal-99 (last-two-digits matching)
/// 2. ordinal-00 through ordinal-09 (last-digit matching)
/// 3. Generic "ordinal" term
///
/// - day: Day number (1-31)
/// - ctx: Context with locale terms
/// Returns: Ordinal suffix string
#let _get-day-ordinal-suffix(day, ctx) = {
  let last-two = calc.rem(day, 100)
  let last-one = calc.rem(day, 10)

  // Try ordinal-10 through ordinal-99 first
  if last-two >= 10 {
    let key = "ordinal-" + zero-pad(last-two, 2)
    let suffix = lookup-term(ctx, key, form: "long", plural: false)
    if suffix != none and suffix != "" and suffix != key {
      return suffix
    }
  }

  // Try ordinal-00 through ordinal-09
  let single-key = "ordinal-" + zero-pad(last-one, 2)
  let single-suffix = lookup-term(ctx, single-key, form: "long", plural: false)
  if (
    single-suffix != none
      and single-suffix != ""
      and single-suffix != single-key
  ) {
    return single-suffix
  }

  // Fallback to generic ordinal term
  let generic = lookup-term(ctx, "ordinal", form: "long", plural: false)
  if generic != none and generic != "" and generic != "ordinal" {
    return generic
  }

  // Ultimate fallback: English ordinals
  if day == 1 or day == 21 or day == 31 { "st" } else if day == 2 or day == 22 {
    "nd"
  } else if day == 3 or day == 23 { "rd" } else { "th" }
}

/// Parse a date string into a datetime object
///
/// Handles formats like:
/// - "2024" -> datetime(year: 2024)
/// - "2024-05" -> datetime(year: 2024, month: 5)
/// - "2024-05-15" -> datetime(year: 2024, month: 5, day: 15)
#let parse-date-string(date-str) = {
  if date-str == "" or date-str == none { return none }

  let s = str(date-str).trim()

  // Try ISO format: YYYY-MM-DD or YYYY/MM/DD
  let iso-match = s.match(_iso-date-pattern)
  if iso-match != none {
    let captures = iso-match.captures
    let year = int(captures.at(0))
    let month = if captures.len() > 1 and captures.at(1) != none {
      int(captures.at(1))
    } else { none }
    let day = if captures.len() > 2 and captures.at(2) != none {
      int(captures.at(2))
    } else { none }

    // CSL uses various month values for seasons:
    // 13-16: Spring, Summer, Fall, Winter (standard CSL seasons)
    // 17-18: Spring, Summer (Down Under / southern hemisphere)
    // 21-24: Spring, Summer, Fall, Winter (alternate representation)
    // Map all to 21-24 for consistent handling
    if month != none {
      let season = if month >= 21 and month <= 24 {
        month
      } else if month >= 13 and month <= 16 {
        // Map 13-16 to 21-24 (same season)
        month + 8
      } else if month == 17 {
        21 // Spring (southern hemisphere)
      } else if month == 18 {
        22 // Summer (southern hemisphere)
      } else if month < 1 or month > 12 {
        // Invalid month - treat as no date
        none
      } else {
        none
      }

      if season != none {
        return (year: year, season: season, _is-season-date: true)
      }

      // Invalid month (negative, >60, etc.) - skip and return year-only
      if month < 1 or month > 12 {
        return datetime(year: year, month: 1, day: 1)
      }
    }

    if month != none and day != none {
      // Validate day using Typst's native datetime arithmetic
      // Get last day of month by going to first of next month minus 1 day
      let (next-year, next-month) = if month == 12 { (year + 1, 1) } else {
        (year, month + 1)
      }
      let last-day-of-month = (
        datetime(year: next-year, month: next-month, day: 1) - duration(days: 1)
      ).day()
      let safe-day = calc.min(day, last-day-of-month)
      return datetime(year: year, month: month, day: safe-day)
    } else if month != none {
      return datetime(year: year, month: month, day: 1)
    } else {
      return datetime(year: year, month: 1, day: 1)
    }
  }

  // Try just year
  let year-match = s.match(_year-only-pattern)
  if year-match != none {
    return datetime(year: int(year-match.captures.at(0)), month: 1, day: 1)
  }

  // Try "Month Year" or "Month Day, Year"
  let text-match = s.match(_text-date-pattern)
  if text-match != none {
    let captures = text-match.captures
    let month-name = lower(captures.at(0))
    let month = _month-map.at(month-name, default: none)
    if month != none {
      let year = int(captures.at(2))
      let day = if captures.at(1) != none { int(captures.at(1)) } else { 1 }
      return datetime(year: year, month: month, day: day)
    }
  }

  // Fallback: try to extract year
  let any-year = s.match(_any-year-pattern)
  if any-year != none {
    return datetime(year: int(any-year.captures.at(0)), month: 1, day: 1)
  }

  none
}

/// Parse BibTeX date fields into a datetime object
///
/// BibTeX can have:
/// - year = {2024}
/// - month = {may} or month = {5}
/// - day = {15}
/// - date = {2024-05-15}  (biblatex)
#let parse-bibtex-date(fields) = {
  // Try biblatex date field first
  let date-field = fields.at("date", default: "")
  if date-field != "" {
    let parsed = parse-date-string(date-field)
    if parsed != none { return parsed }
  }

  // Fall back to year/month/day fields
  let year-str = fields.at("year", default: "")
  if year-str == "" { return none }

  let year = int(year-str)
  if year == none { return none }

  let month = 1
  let month-str = fields.at("month", default: "")
  if month-str != "" {
    // Month might be name or number
    let lower-month = lower(str(month-str))
    let month-num = _month-map.at(lower-month, default: none)
    if month-num != none {
      month = month-num
    } else {
      let parsed = int(month-str)
      if parsed != none { month = parsed }
    }
  }

  let day = 1
  let day-str = fields.at("day", default: "")
  if day-str != "" {
    let parsed = int(day-str)
    if parsed != none { day = parsed }
  }

  // CSL uses various month values for seasons:
  // 13-16: Spring, Summer, Fall, Winter (standard CSL seasons)
  // 17-18: Spring, Summer (Down Under / southern hemisphere)
  // 21-24: Spring, Summer, Fall, Winter (alternate representation)
  let season = if month >= 21 and month <= 24 {
    month
  } else if month >= 13 and month <= 16 {
    month + 8 // Map 13-16 to 21-24
  } else if month == 17 {
    21 // Spring
  } else if month == 18 {
    22 // Summer
  } else {
    none
  }

  if season != none {
    (year: year, season: season, _is-season-date: true)
  } else if month < 1 or month > 12 {
    // Invalid month - return year-only date
    datetime(year: year, month: 1, day: 1)
  } else {
    datetime(year: year, month: month, day: day)
  }
}

/// Check if date has specific component
/// (We track this via metadata since datetime always has all components)
#let date-has-component(fields, component) = {
  if component == "year" {
    fields.at("year", default: "") != "" or fields.at("date", default: "") != ""
  } else if component == "month" {
    (
      fields.at("month", default: "") != ""
        or fields.at("date", default: "").contains("-")
    )
  } else if component == "day" {
    // Note: .matches() returns empty array () when no match, not none
    // So we check .len() > 0 instead of != none
    (
      fields.at("day", default: "") != ""
        or fields.at("date", default: "").matches(_full-iso-pattern).len() > 0
    )
  } else {
    false
  }
}

/// Format a date-part using Typst's native datetime
///
/// - dt: datetime object or season dict
/// - name: "year", "month", or "day"
/// - form: CSL form ("numeric", "numeric-leading-zeros", "ordinal", "long", "short")
/// - ctx: Context for locale terms (used for ordinals)
#let format-date-part(dt, name, form, ctx) = {
  if dt == none { return "" }

  // Handle season dates (months 21-24 in CSL)
  if type(dt) == dictionary and dt.at("_is-season-date", default: false) {
    if name == "year" {
      let year = dt.year
      if year < 0 {
        let bc-term = lookup-term(ctx, "bc", form: "long", plural: false)
        let bc-str = if bc-term != none { bc-term } else { "BC" }
        str(-year) + bc-str
      } else if year < 1000 {
        let ad-term = lookup-term(ctx, "ad", form: "long", plural: false)
        let ad-str = if ad-term != none { ad-term } else { "AD" }
        str(year) + ad-str
      } else {
        str(year)
      }
    } else if name == "month" {
      // Season terms: 21=spring, 22=summer, 23=fall, 24=winter
      let season-num = dt.season
      let season-key = "season-" + if season-num < 10 { "0" } else { "" } + str(
        season-num,
      )
      let season-term = lookup-term(ctx, season-key, form: "long", plural: false)
      if season-term != none and season-term != "" {
        season-term
      } else {
        // Fallback
        if season-num == 21 { "Spring" } else if season-num == 22 {
          "Summer"
        } else if season-num == 23 { "Fall" } else if season-num == 24 {
          "Winter"
        } else { "" }
      }
    } else {
      // No day for season dates
      ""
    }
  } else if name == "year" {
    // Note: year-suffix is NOT added here - it's handled by CSL's <text variable="year-suffix"/>
    let year = dt.year()
    let year-str = if year < 0 {
      // Negative year: display as positive with BC suffix
      str(-year)
    } else if year < 1000 {
      // Years before 1000 AD: no zero-padding, will add era suffix
      str(year)
    } else {
      // Modern years: use standard 4-digit format
      dt.display("[year]")
    }
    // CSL spec: years before 1000 should include era suffix
    if year < 0 {
      // BC year
      let bc-term = lookup-term(ctx, "bc", form: "long", plural: false)
      let bc-str = if bc-term != none { bc-term } else { "BC" }
      year-str + bc-str
    } else if year < 1000 {
      // AD year (before 1000)
      let ad-term = lookup-term(ctx, "ad", form: "long", plural: false)
      let ad-str = if ad-term != none { ad-term } else { "AD" }
      year-str + ad-str
    } else {
      year-str
    }
  } else if name == "month" {
    if form == "numeric" {
      dt.display("[month padding:none]")
    } else if form == "numeric-leading-zeros" {
      dt.display("[month]")
    } else if form == "short" {
      // Use locale month term with -short suffix
      let month-num = dt.month()
      let month-key = (
        "month-"
          + if month-num < 10 { "0" } else { "" }
          + str(month-num)
          + "-short"
      )
      let month-term = lookup-term(ctx, month-key, form: "long", plural: false)
      if month-term != none and month-term != "" {
        month-term
      } else {
        // Fallback to Typst short month
        dt.display("[month repr:short]")
      }
    } else if form == "long" {
      // Use locale month term
      let month-num = dt.month()
      let month-key = (
        "month-" + if month-num < 10 { "0" } else { "" } + str(month-num)
      )
      let month-term = lookup-term(ctx, month-key, form: "long", plural: false)
      if month-term != none and month-term != "" {
        month-term
      } else {
        // Fallback to Typst long month
        dt.display("[month repr:long]")
      }
    } else {
      dt.display("[month]")
    }
  } else if name == "day" {
    if form == "numeric" {
      dt.display("[day padding:none]")
    } else if form == "numeric-leading-zeros" {
      dt.display("[day]")
    } else if form == "ordinal" {
      let day = dt.day()
      // CSL locale option: limit-day-ordinals-to-day-1
      // If true, only day 1 uses ordinal form, others use numeric
      let locale-options = ctx
        .at("locale", default: (:))
        .at("options", default: (:))
      let limit-ordinals = locale-options.at(
        "limit-day-ordinals-to-day-1",
        default: false,
      )
      if limit-ordinals and day != 1 {
        str(day)
      } else {
        // Use locale-aware ordinal suffixes
        let suffix = _get-day-ordinal-suffix(day, ctx)
        str(day) + suffix
      }
    } else {
      dt.display("[day]")
    }
  } else {
    ""
  }
}

/// Format a complete date
///
/// - dt: datetime object
/// - form: "numeric" or "text"
/// - date-parts: "year", "year-month", or "year-month-day"
/// - ctx: Context for locale
/// - fields: Optional date source fields for checking which components actually exist
/// - overrides: Optional dict of inline date-part overrides from CSL (name -> attrs)
#let format-date-with-form(
  dt,
  form,
  date-parts,
  ctx,
  fields: none,
  overrides: none,
) = {
  if dt == none { return [] }

  // Determine which parts to show based on date-parts attribute
  let parts-to-show = if date-parts == "year" {
    ("year",)
  } else if date-parts == "year-month" {
    ("year", "month")
  } else {
    ("year", "month", "day")
  }

  // Check if locale has a date format definition for this form
  let locale-dates = ctx.at("locale", default: (:)).at("dates", default: (:))
  let date-format = locale-dates.at(form, default: none)

  if date-format != none {
    // Use locale-defined date format
    let format-parts = date-format.at("parts", default: ())
    let result-parts = ()
    let override-dict = if overrides != none { overrides } else { (:) }

    for part in format-parts {
      let part-name = part.at("name", default: "")

      // Skip parts not in date-parts selection
      if part-name not in parts-to-show {
        continue
      }

      // Skip parts that don't exist in the actual date data
      if fields != none and not date-has-component(fields, part-name) {
        continue
      }

      // Check for inline overrides from CSL
      let override-attrs = override-dict.at(part-name, default: (:))

      // CSL spec: month defaults to "long" for text form, day/year default to "numeric"
      let default-form = if part-name == "month" {
        if form == "text" { "long" } else { "numeric" }
      } else {
        "numeric"
      }

      // Priority: override > locale > default
      let part-form = override-attrs.at("form", default: part.at(
        "form",
        default: "",
      ))
      if part-form == "" { part-form = default-form }

      let part-prefix = override-attrs.at("prefix", default: part.at(
        "prefix",
        default: "",
      ))
      let part-suffix = override-attrs.at("suffix", default: part.at(
        "suffix",
        default: "",
      ))

      let formatted = format-date-part(dt, part-name, part-form, ctx)
      if formatted != "" {
        result-parts.push([#part-prefix#formatted#part-suffix])
      }
    }

    result-parts.join()
  } else {
    // Fallback to hardcoded default format
    // First, check which parts actually exist in the date data
    let has-year = fields == none or date-has-component(fields, "year")
    let has-month = fields == none or date-has-component(fields, "month")
    let has-day = fields == none or date-has-component(fields, "day")

    // Combine with date-parts attribute restrictions
    let show-year = has-year
    let show-month = (
      (date-parts == "year-month" or date-parts == "year-month-day")
        and has-month
    )
    let show-day = date-parts == "year-month-day" and has-day

    if form == "text" {
      // Text format: "January 15, 2024" or "January 2024" or "2024"
      if show-day and show-month {
        dt.display("[month repr:long] [day padding:none], [year]")
      } else if show-month {
        dt.display("[month repr:long] [year]")
      } else {
        dt.display("[year]")
      }
    } else {
      // Numeric format: "2024-01-15" or "2024-01" or "2024"
      if show-day and show-month {
        dt.display("[year]-[month]-[day]")
      } else if show-month {
        dt.display("[year]-[month]")
      } else {
        dt.display("[year]")
      }
    }
  }
}

/// Main date formatting function for CSL
///
/// - date: datetime object or date string or fields dict
/// - attrs: Date formatting attributes from CSL
/// - ctx: Context
#let format-date(date, attrs, ctx) = {
  // Parse if needed
  let dt = if type(date) == datetime {
    date
  } else if type(date) == str {
    parse-date-string(date)
  } else if type(date) == dictionary {
    parse-bibtex-date(date)
  } else {
    none
  }

  if dt == none { return [] }

  let form = attrs.at("form", default: "numeric")
  let date-parts = attrs.at("date-parts", default: "year-month-day")

  format-date-with-form(dt, form, date-parts, ctx)
}

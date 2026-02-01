// citrus - Date Handler
//
// Handles <date> CSL element.

#import "../core/mod.typ": finalize
#import "../data/collapsing.typ": num-to-suffix
#import "../text/dates.typ": (
  date-has-component, format-date-part, format-date-with-form,
  parse-bibtex-date,
)

/// Convert year-suffix to letter string
/// Handles both numeric (0, 1, 2) and legacy string formats
#let _suffix-to-string(suffix) = {
  if suffix == none or suffix == "" { return "" }
  if type(suffix) == int { return num-to-suffix(suffix) }
  str(suffix)
}

/// Check if year-suffix should be auto-appended to this date
/// CSL spec: "By default, the year-suffix is appended the first year rendered
/// through cs:date... but its location can be controlled by explicitly
/// rendering the 'year-suffix' variable using cs:text"
#let _should-append-year-suffix(ctx) = {
  // Get year-suffix value from context
  let suffix = ctx.at("year-suffix", default: none)
  if suffix == none or suffix == "" { return false }

  // Check if style has explicit year-suffix rendering
  // If has-explicit-year-suffix is true, don't auto-append
  let has-explicit = ctx.at("has-explicit-year-suffix", default: false)
  if has-explicit { return false }

  // Check if we've already appended year-suffix in this render pass
  let already-done = ctx.at("year-suffix-done", default: false)
  if already-done { return false }

  true
}

/// Handle <date> element
/// The third parameter is ignored (kept for dispatch table compatibility)
#let handle-date(node, ctx, .._rest) = {
  // Support suppress-year for year-suffix collapse
  // But still render year-suffix if present (for implicit year-suffix styles)
  if ctx.at("suppress-year", default: false) {
    // Check if we should render just the year-suffix
    let suffix = ctx.at("year-suffix", default: none)
    let has-explicit = ctx.at("has-explicit-year-suffix", default: false)
    if suffix != none and suffix != "" and not has-explicit {
      // Render only the year-suffix letter (without the year)
      return _suffix-to-string(suffix)
    }
    return []
  }

  let attrs = node.at("attrs", default: (:))
  let children = node.at("children", default: ())
  let variable = attrs.at("variable", default: "issued")

  // Check for literal date first (e.g., "in press", "forthcoming")
  // CSL-JSON: { "issued": { "literal": "(in press)" } }
  let literal-date = ctx.fields.at("literal", default: "")
  if literal-date != "" {
    return finalize(literal-date, attrs)
  }

  // Parse date based on variable attribute
  let dt = if variable == "issued" {
    parse-bibtex-date(ctx.fields)
  } else if variable == "accessed" {
    // Parse urldate for accessed date
    let urldate = ctx.fields.at("urldate", default: "")
    if urldate != "" {
      parse-bibtex-date((year: urldate, date: urldate))
    } else { none }
  } else if variable == "original-date" {
    // Parse origdate for original-date
    let origdate = ctx.fields.at("origdate", default: "")
    if origdate != "" {
      parse-bibtex-date((year: origdate, date: origdate))
    } else { none }
  } else if variable == "event-date" {
    // Parse eventdate
    let eventdate = ctx.fields.at("eventdate", default: "")
    if eventdate != "" {
      parse-bibtex-date((year: eventdate, date: eventdate))
    } else { none }
  } else {
    // Default to issued
    parse-bibtex-date(ctx.fields)
  }

  // Check for date children (inline date-parts)
  let date-part-nodes = children.filter(c => (
    type(c) == dictionary and c.at("tag", default: "") == "date-part"
  ))

  if dt != none {
    // Check if we should auto-append year-suffix
    let append-suffix = _should-append-year-suffix(ctx)
    let year-suffix = if append-suffix {
      _suffix-to-string(ctx.at("year-suffix", default: none))
    } else { "" }

    // Get date source fields for component checking
    let date-fields = if variable == "issued" {
      ctx.fields
    } else if variable == "accessed" {
      // Use accessed-* fields if available, otherwise fall back to urldate
      let accessed-year = ctx.fields.at("accessed-year", default: "")
      if accessed-year != "" {
        (
          year: accessed-year,
          month: ctx.fields.at("accessed-month", default: ""),
          day: ctx.fields.at("accessed-day", default: ""),
          date: ctx.fields.at("urldate", default: ""),
        )
      } else {
        let urldate = ctx.fields.at("urldate", default: "")
        if urldate != "" { (year: urldate, date: urldate) } else { (:) }
      }
    } else if variable == "original-date" {
      let origdate = ctx.fields.at("origdate", default: "")
      if origdate != "" { (year: origdate, date: origdate) } else { (:) }
    } else if variable == "event-date" {
      let eventdate = ctx.fields.at("eventdate", default: "")
      if eventdate != "" { (year: eventdate, date: eventdate) } else { (:) }
    } else {
      ctx.fields
    }

    let result = if date-part-nodes.len() > 0 {
      // Use inline date-part specifications
      let parts = ()
      let year-rendered = false
      for dp in date-part-nodes {
        let dp-attrs = dp.at("attrs", default: (:))
        let dp-name = dp-attrs.at("name", default: "")
        // CSL spec: month defaults to "long", day/year default to "numeric"
        let default-form = if dp-name == "month" { "long" } else { "numeric" }
        let dp-form = dp-attrs.at("form", default: default-form)
        let dp-prefix = dp-attrs.at("prefix", default: "")
        let dp-suffix = dp-attrs.at("suffix", default: "")

        // Check if the date actually has this component
        if not date-has-component(date-fields, dp-name) {
          continue
        }

        let formatted = format-date-part(dt, dp-name, dp-form, ctx)
        if formatted != "" {
          // Auto-append year-suffix after the first year part
          if dp-name == "year" and not year-rendered and year-suffix != "" {
            year-rendered = true
            parts.push([#dp-prefix#formatted#year-suffix#dp-suffix])
          } else {
            parts.push([#dp-prefix#formatted#dp-suffix])
          }
        }
      }
      parts.join()
    } else {
      // Use form attribute or default
      let form = attrs.at("form", default: "numeric")
      let date-parts = attrs.at("date-parts", default: "year-month-day")
      let date-result = format-date-with-form(
        dt,
        form,
        date-parts,
        ctx,
        fields: date-fields,
      )
      // For localized dates, append year-suffix at the end (year is typically last)
      if year-suffix != "" {
        [#date-result#year-suffix]
      } else {
        date-result
      }
    }

    finalize(result, attrs)
  } else { [] }
}

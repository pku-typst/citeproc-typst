// citeproc-typst - CSL Condition Evaluator
//
// Evaluates CSL conditional expressions (if/else-if)
// Includes CSL-M extension conditions

#import "variables.typ": get-variable, has-variable

/// Check if entry type matches
#let check-type(ctx, type-list) = {
  let entry-type = ctx.entry-type

  // Map BibTeX types to CSL types (including CSL-M legal types)
  let type-map = (
    // Standard CSL types
    "article": "article-journal",
    "book": "book",
    "inbook": "chapter",
    "incollection": "chapter",
    "inproceedings": "paper-conference",
    "conference": "paper-conference",
    "phdthesis": "thesis",
    "mastersthesis": "thesis",
    "thesis": "thesis",
    "techreport": "report",
    "report": "report",
    "misc": "document",
    "online": "webpage",
    "webpage": "webpage",
    "patent": "patent",
    "standard": "legislation",
    "dataset": "dataset",
    "software": "software",
    "periodical": "periodical",
    "collection": "book",
    // CSL-M legal types
    "legal_case": "legal_case",
    "case": "legal_case",
    "legislation": "legislation",
    "statute": "legislation",
    "bill": "bill",
    "hearing": "hearing",
    "regulation": "regulation",
    "treaty": "treaty",
    "classic": "classic",
    "video": "video",
    "legal_commentary": "legal_commentary",
    "gazette": "gazette",
  )

  let csl-type = type-map.at(entry-type, default: entry-type)

  // Split type list and check - only check mapped CSL type
  let types = type-list.split(" ")
  types.any(t => t == csl-type)
}

/// Check if variable exists
#let check-variable(ctx, var-list) = {
  let vars = var-list.split(" ")
  vars.any(v => has-variable(ctx, v))
}

/// Check if value is numeric
/// CSL spec: numeric if it contains only numeric digits, or starts with numeric digits
/// (e.g., "206–210", "1st", "2nd" are all considered numeric)
#let check-is-numeric(ctx, var-name) = {
  let val = get-variable(ctx, var-name)
  if val == "" { return false }

  // CSL considers a value numeric if it starts with a digit
  // Examples: "206", "206–210", "1st", "5a" are all numeric
  let first-char = val.first()
  first-char.match(regex("^[0-9]$")) != none
}

/// Evaluate a CSL condition
///
/// - attrs: Condition attributes (type, variable, match, etc.)
/// - ctx: Interpretation context
/// Returns: bool
#let eval-condition(attrs, ctx) = {
  let match-mode = attrs.at("match", default: "all")

  let conditions = ()

  // Type condition
  if "type" in attrs {
    conditions.push(check-type(ctx, attrs.type))
  }

  // Variable condition
  if "variable" in attrs {
    conditions.push(check-variable(ctx, attrs.variable))
  }

  // Is-numeric condition
  if "is-numeric" in attrs {
    conditions.push(check-is-numeric(ctx, attrs.at("is-numeric")))
  }

  // Is-uncertain-date condition
  // CSL spec: true if date has uncertainty markers (circa, ~, ?)
  if "is-uncertain-date" in attrs {
    let date-var = attrs.at("is-uncertain-date")
    let date-val = get-variable(ctx, date-var)
    let is-uncertain = if date-val != "" {
      // Check for uncertainty markers
      let s = lower(str(date-val))
      (
        s.contains("circa")
          or s.contains("c.")
          or s.contains("~")
          or s.contains("?")
          or s.contains("ca.")
          or s.contains("approximately")
      )
    } else { false }
    conditions.push(is-uncertain)
  }

  // Has-day condition (for dates) - standard CSL, not CSL-M
  // Note: CSL-M has its own has-day handled below
  if (
    "has-day" in attrs
      and "has-day" not in ("has-to-month-or-season", "has-year-only")
  ) {
    let date-var = attrs.at("has-day")
    let date-val = get-variable(ctx, date-var)
    let has-day-result = if date-val != "" {
      // Check for day component in various formats
      let s = str(date-val)
      // YYYY-MM-DD format
      let iso-match = s.match(regex("^\d{4}[-/]\d{1,2}[-/]\d{1,2}"))
      if iso-match != none {
        true
      } else {
        // "Month Day, Year" format
        let text-match = s.match(regex("[A-Za-z]+\s+\d{1,2},?\s+\d{4}"))
        text-match != none
      }
    } else { false }
    conditions.push(has-day-result)
  }

  // Position condition (first, subsequent, ibid, ibid-with-locator, near-note)
  if "position" in attrs {
    let pos-value = attrs.at("position")
    let current-pos = ctx.at("position", default: "first")

    // Check if current position matches any of the specified positions
    let positions = pos-value.split(" ")
    let matches = positions.any(p => {
      if p == "first" { current-pos == "first" } else if p == "subsequent" {
        (
          current-pos == "subsequent"
            or current-pos == "ibid"
            or current-pos == "ibid-with-locator"
        )
      } else if p == "ibid" { current-pos == "ibid" } else if (
        p == "ibid-with-locator"
      ) { current-pos == "ibid-with-locator" } else if p == "near-note" {
        // near-note: true if previous citation to same item is within near-note-distance
        let near-note-distance = ctx.style.at(
          "near-note-distance",
          default: 5,
        )
        let last-note = ctx.at("last-note-number", default: none)
        let current-note = ctx.at("note-number", default: none)
        if last-note != none and current-note != none {
          let distance = current-note - last-note
          distance <= near-note-distance
        } else {
          false
        }
      } else if p == "far-note" {
        // CSL-M extension: far-note is the opposite of near-note
        let near-note-distance = ctx.style.at(
          "near-note-distance",
          default: 5,
        )
        let last-note = ctx.at("last-note-number", default: none)
        let current-note = ctx.at("note-number", default: none)
        if last-note != none and current-note != none {
          let distance = current-note - last-note
          distance > near-note-distance
        } else {
          true // No previous citation means far
        }
      } else { false }
    })
    conditions.push(matches)
  }

  // Locator condition (check if locator/supplement is present)
  if "locator" in attrs {
    let has-locator = ctx.at("locator", default: none) != none
    conditions.push(has-locator)
  }

  // =========================================================================
  // CSL-M Extension Conditions
  // =========================================================================

  // Context condition (CSL-M): check if rendering in citation or bibliography
  if "context" in attrs {
    let context-value = attrs.at("context")
    let current-context = ctx.at("render-context", default: "bibliography")
    conditions.push(context-value == current-context)
  }

  // Genre condition (CSL-M): check genre field for specific values
  if "genre" in attrs {
    let genre-list = attrs.at("genre").split(" ")
    let entry-genre = get-variable(ctx, "genre")
    conditions.push(genre-list.any(g => g == entry-genre))
  }

  // Has-day condition (CSL-M): check if date has day component
  if "has-day" in attrs {
    let date-var = attrs.at("has-day")
    let date-val = get-variable(ctx, date-var)
    // Check if the date string contains day component (YYYY-MM-DD format)
    let has-day = if date-val != "" {
      let parts = date-val.split("-")
      parts.len() >= 3 and parts.at(2, default: "") != ""
    } else { false }
    conditions.push(has-day)
  }

  // Has-year-only condition (CSL-M): check if date has only year
  if "has-year-only" in attrs {
    let date-var = attrs.at("has-year-only")
    let date-val = get-variable(ctx, date-var)
    let has-year-only = if date-val != "" {
      let parts = date-val.split("-")
      parts.len() == 1 or (parts.len() >= 2 and parts.at(1, default: "") == "")
    } else { false }
    conditions.push(has-year-only)
  }

  // Has-to-month-or-season condition (CSL-M): date has month/season but no day
  if "has-to-month-or-season" in attrs {
    let date-var = attrs.at("has-to-month-or-season")
    let date-val = get-variable(ctx, date-var)
    let has-month-only = if date-val != "" {
      let parts = date-val.split("-")
      (
        parts.len() >= 2
          and parts.at(1, default: "") != ""
          and (parts.len() < 3 or parts.at(2, default: "") == "")
      )
    } else { false }
    conditions.push(has-month-only)
  }

  // Is-multiple condition (CSL-M): check if variable contains multiple values (has space)
  if "is-multiple" in attrs {
    let var-name = attrs.at("is-multiple")
    let val = get-variable(ctx, var-name)
    conditions.push(val != "" and val.contains(" "))
  }

  // No conditions means true (for <else>)
  if conditions.len() == 0 {
    return true
  }

  // Apply match mode (including CSL-M "nand")
  if match-mode == "any" {
    conditions.any(c => c)
  } else if match-mode == "none" {
    not conditions.any(c => c)
  } else if match-mode == "nand" {
    // CSL-M extension: true if at least one condition is false
    not conditions.all(c => c)
  } else {
    // "all" is default
    conditions.all(c => c)
  }
}

// =============================================================================
// CSL-M Nested Conditions (cs:conditions element)
// =============================================================================

/// Evaluate nested conditions (CSL-M extension)
///
/// The cs:conditions element allows grouping multiple cs:condition children
/// with a match attribute applied to the group.
///
/// - conditions-node: The cs:conditions element
/// - ctx: Interpretation context
/// Returns: bool
#let eval-nested-conditions(conditions-node, ctx) = {
  let attrs = conditions-node.at("attrs", default: (:))
  let children = conditions-node.at("children", default: ())
  let match-mode = attrs.at("match", default: "all")

  // Evaluate each child condition
  let results = ()
  for child in children {
    if type(child) != dictionary { continue }
    if child.at("tag", default: "") != "condition" { continue }

    let child-attrs = child.at("attrs", default: (:))
    results.push(eval-condition(child-attrs, ctx))
  }

  // Apply match mode to results
  if match-mode == "any" {
    results.any(r => r)
  } else if match-mode == "none" {
    not results.any(r => r)
  } else if match-mode == "nand" {
    not results.all(r => r)
  } else {
    results.all(r => r)
  }
}

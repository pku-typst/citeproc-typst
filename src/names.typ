// citeproc-typst - Name Formatting
//
// Formats author/editor names according to CSL rules
// Includes CSL-M extension: cs:institution for institutional authors

#import "locales.typ": is-cjk-name, lookup-term

/// Apply name-part formatting (text-case)
#let format-name-part(text, attrs) = {
  if text == "" { return "" }

  let result = text

  if "text-case" in attrs {
    let text-case = attrs.at("text-case")
    if text-case == "uppercase" {
      result = upper(result)
    } else if text-case == "lowercase" {
      result = lower(result)
    } else if text-case == "capitalize-first" {
      if result.len() > 0 {
        result = upper(result.first()) + result.slice(1)
      }
    }
  }

  result
}

/// Format a single name
///
/// - name: Parsed name dict (family, given, prefix, suffix)
/// - attrs: Name formatting attributes from CSL
/// - ctx: Context
/// - position: Position in name list (1-indexed)
/// - name-parts: Dict of name-part formatting (from <name-part> elements)
#let format-single-name(
  name,
  attrs,
  ctx,
  position: 1,
  name-parts: (:),
) = {
  let family = name.at("family", default: "")
  let given = name.at("given", default: "")
  let prefix = name.at("prefix", default: "") // "von", "de", etc.
  let suffix = name.at("suffix", default: "") // "Jr.", "III", etc.

  let is-chinese = is-cjk-name(name)

  // Get formatting options from attrs (or style defaults)
  let name-as-sort-order = attrs.at(
    "name-as-sort-order",
    default: ctx.style.name-as-sort-order,
  )
  let initialize-with = attrs.at(
    "initialize-with",
    default: ctx.style.initialize-with,
  )
  let sort-separator = attrs.at(
    "sort-separator",
    default: ctx.style.sort-separator,
  )
  let name-form = attrs.at("form", default: "long")

  // Apply name-part formatting
  let family-part-attrs = name-parts.at("family", default: (:))
  let given-part-attrs = name-parts.at("given", default: (:))

  let formatted-family = format-name-part(family, family-part-attrs)
  let formatted-given = given

  // Short form: only family name
  if name-form == "short" {
    return formatted-family
  }

  // Initialize given name if required
  if initialize-with != none and given != "" and not is-chinese {
    // Split given names and take initials
    let parts = given.split(regex("[ -]+")).filter(p => p != "")
    let initialize-hyphen = ctx.style.initialize-with-hyphen

    // Build initials with initialize-with after each
    let initials = parts.map(p => {
      if p.len() > 0 { upper(p.first()) + initialize-with } else { "" }
    })

    // Join with hyphen if needed
    if initialize-hyphen and given.contains("-") {
      formatted-given = initials.join("-")
    } else {
      formatted-given = initials.join("")
    }

    // Trim trailing space from initialize-with
    formatted-given = formatted-given.trim(at: end)
  }

  // Apply given name part formatting
  formatted-given = format-name-part(formatted-given, given-part-attrs)

  // Determine name order
  let use-sort-order = (
    name-as-sort-order == "all"
      or (name-as-sort-order == "first" and position == 1)
  )

  // Build name string
  if is-chinese {
    // Chinese: 姓名 (no separator)
    formatted-family + formatted-given
  } else if use-sort-order {
    // Sort order: Family Given Suffix (with sort-separator, no comma before suffix)
    // Per GB/T 7714-2025: "Sodeman W A Jr" not "Sodeman W A, Jr"

    // Handle prefix (demote-non-dropping-particle setting)
    let demote = ctx.style.demote-non-dropping-particle
    if prefix != "" and demote == "never" {
      // Prefix stays with family name
      formatted-family = prefix + " " + formatted-family
    }

    // Build name parts
    let result = formatted-family
    if formatted-given != "" {
      result = [#result#sort-separator#formatted-given]
    }
    // Add suffix without comma (per GB/T 7714)
    if suffix != "" {
      result = [#result #suffix]
    }
    result
  } else {
    // Display order: Given Family
    let parts = ()
    if formatted-given != "" { parts.push(formatted-given) }
    if prefix != "" { parts.push(prefix) }
    parts.push(formatted-family)
    if suffix != "" { parts.push(suffix) }
    parts.join(" ")
  }
}

/// Format a list of names
///
/// - names: Array of parsed name dicts
/// - attrs: Name formatting attributes
/// - ctx: Context
#let format-names(names, attrs, ctx) = {
  if names.len() == 0 { return [] }

  // ==========================================================================
  // CSL-M suppress-min / suppress-max
  // ==========================================================================
  // suppress-min: suppress names entirely if count <= value
  // suppress-max: suppress names entirely if count >= value
  // suppress-min="0": suppress all personal names (leave institutions)
  // suppress-max with form="count": show count only if > max

  let suppress-min = attrs.at("suppress-min", default: none)
  let suppress-max = attrs.at("suppress-max", default: none)

  if suppress-min != none {
    let min-val = if type(suppress-min) == str { int(suppress-min) } else {
      suppress-min
    }
    // suppress-min="0" is special: suppresses personal names only
    if min-val == 0 {
      // Filter out personal names, keep only institutional
      let institutional = names.filter(n => is-institutional-name(n))
      if institutional.len() == 0 { return [] }
      // Continue with institutional names only
      names = institutional
    } else if names.len() <= min-val {
      return []
    }
  }

  if suppress-max != none {
    let max-val = if type(suppress-max) == str { int(suppress-max) } else {
      suppress-max
    }
    if names.len() >= max-val {
      // For form="count", we return the count instead of suppressing
      let name-form = attrs.at("form", default: "long")
      if name-form == "count" {
        return str(names.len())
      }
      return []
    }
  }

  // Get et-al settings
  let et-al-min = attrs.at("et-al-min", default: none)
  let et-al-use-first = attrs.at("et-al-use-first", default: none)

  // Fallback to bibliography settings (with null-safety for citation-only styles)
  let bib = ctx.style.at("bibliography", default: none)
  if et-al-min == none {
    et-al-min = if bib != none { bib.at("et-al-min", default: 4) } else { 4 }
  }
  if et-al-use-first == none {
    et-al-use-first = if bib != none {
      bib.at("et-al-use-first", default: 3)
    } else { 3 }
  }

  // Convert string to int if needed
  if type(et-al-min) == str { et-al-min = int(et-al-min) }
  if type(et-al-use-first) == str { et-al-use-first = int(et-al-use-first) }

  // Determine how many names to show
  let use-et-al = names.len() >= et-al-min
  let show-count = if use-et-al { et-al-use-first } else { names.len() }

  // Parse name-part elements if present (would be passed via attrs in a more complete impl)
  let name-parts = (:)

  // Format individual names
  let formatted = ()
  for (i, name) in names
    .slice(0, calc.min(show-count, names.len()))
    .enumerate() {
    formatted.push(format-single-name(
      name,
      attrs,
      ctx,
      position: i + 1,
      name-parts: name-parts,
    ))
  }

  // Get delimiters
  let delimiter = attrs.at("delimiter", default: ctx.style.name-delimiter)
  let and-mode = attrs.at("and", default: ctx.style.and-term) // "text", "symbol", or none
  let delimiter-precedes-last = attrs.at(
    "delimiter-precedes-last",
    default: "contextual",
  )

  // Get the "and" term
  let and-term = if and-mode == "symbol" {
    lookup-term(ctx, "and", form: "symbol")
  } else if and-mode == "text" {
    lookup-term(ctx, "and", form: "long")
  } else {
    none
  }

  // Join names
  let result = if formatted.len() == 1 {
    formatted.first()
  } else if formatted.len() == 2 and not use-et-al and and-term != none {
    // Two names with "and"
    [#formatted.first() #and-term #formatted.last()]
  } else if and-term != none and not use-et-al {
    // Multiple names with "and" before last
    let all-but-last = formatted.slice(0, -1)
    let last = formatted.last()

    let use-delimiter-before-last = (
      (delimiter-precedes-last == "always")
        or (delimiter-precedes-last == "contextual" and formatted.len() > 2)
    )

    if use-delimiter-before-last {
      [#all-but-last.join(delimiter)#delimiter#and-term #last]
    } else {
      [#all-but-last.join(delimiter) #and-term #last]
    }
  } else {
    formatted.join(delimiter)
  }

  // Add et al if needed
  if use-et-al {
    let et-al = lookup-term(ctx, "et-al", form: "long")
    [#result#delimiter#et-al]
  } else {
    result
  }
}

// =============================================================================
// CSL-M Institution Support
// =============================================================================

/// Check if a name is an institutional name (CSL-M extension)
///
/// In CSL-M, institutional names are stored with "literal" field or
/// with only "family" field and no "given" field.
///
/// - name: Name dict
/// Returns: bool
#let is-institutional-name(name) = {
  // Check for literal name (explicit institution)
  if "literal" in name { return true }

  // Check for family-only name (no given name)
  let family = name.at("family", default: "")
  let given = name.at("given", default: "")

  family != "" and given == ""
}

/// Format an institutional name (CSL-M extension)
///
/// Institutional names can have multiple subunits separated by "|"
///
/// - name: Name dict with "literal" or "family" field
/// - attrs: Institution formatting attributes
/// - ctx: Context
#let format-institution(name, attrs, ctx) = {
  // Get the institution name
  let full-name = if "literal" in name {
    name.literal
  } else {
    name.at("family", default: "")
  }

  if full-name == "" { return "" }

  // Parse subunits (separated by "|" in CSL-M)
  let subunits = full-name.split("|").map(s => s.trim())

  // Get institution formatting options
  let delimiter = attrs.at("delimiter", default: ", ")
  let use-first = attrs.at("use-first", default: none)
  let use-last = attrs.at("use-last", default: none)
  let substitute-use-first = attrs.at("substitute-use-first", default: none)
  let reverse-order = attrs.at("reverse-order", default: "false") == "true"
  let institution-parts = attrs.at("institution-parts", default: "long")

  // Reverse order if requested (for "big endian" display)
  if reverse-order {
    subunits = subunits.rev()
  }

  // Apply use-first and use-last truncation
  if use-first != none or use-last != none {
    let first-count = if use-first != none { int(use-first) } else { 0 }
    let last-count = if use-last != none { int(use-last) } else { 0 }

    if first-count + last-count < subunits.len() {
      let first-part = subunits.slice(0, first-count)
      let last-part = subunits.slice(subunits.len() - last-count)
      subunits = first-part + last-part
    }
  }

  // Handle short form (use abbreviation if available)
  if institution-parts == "short" {
    // In a full implementation, this would check for abbreviations
    // For now, just use the subunits as-is
  }

  subunits.join(delimiter)
}

/// Format names with institutional name support (CSL-M extension)
///
/// This function handles mixed personal and institutional names.
///
/// - names: Array of parsed name dicts
/// - attrs: Name formatting attributes
/// - institution-attrs: Institution formatting attributes (from cs:institution)
/// - ctx: Context
#let format-names-with-institutions(
  names,
  attrs,
  institution-attrs,
  ctx,
) = {
  if names.len() == 0 { return [] }

  // Separate personal and institutional names
  let personal-names = ()
  let inst-groups = () // Groups of (personal authors, institution)

  let current-personal = ()
  for name in names {
    if is-institutional-name(name) {
      // Start a new group with current personal names + this institution
      inst-groups.push((
        personal: current-personal,
        institution: name,
      ))
      current-personal = ()
    } else {
      current-personal.push(name)
    }
  }

  // Handle trailing personal names (unaffiliated)
  let unaffiliated = current-personal

  // If no institutions, just format as regular names
  if inst-groups.len() == 0 {
    return format-names(names, attrs, ctx)
  }

  // Format each group
  let group-delimiter = institution-attrs.at("delimiter", default: ", ")
  let and-mode = institution-attrs.at("and", default: none)

  let formatted-groups = ()

  for group in inst-groups {
    let parts = ()

    // Format personal names in this group
    if group.personal.len() > 0 {
      parts.push(format-names(group.personal, attrs, ctx))
    }

    // Format institution
    let inst-formatted = format-institution(
      group.institution,
      institution-attrs,
      ctx,
    )
    if inst-formatted != "" {
      parts.push(inst-formatted)
    }

    if parts.len() > 0 {
      formatted-groups.push(parts.join(group-delimiter))
    }
  }

  // Add unaffiliated authors at the beginning with "with" term
  let result = if unaffiliated.len() > 0 and formatted-groups.len() > 0 {
    let with-term = lookup-term(ctx, "with", form: "long")
    if with-term == "" { with-term = "with" }
    let unaffiliated-formatted = format-names(unaffiliated, attrs, ctx)
    [#unaffiliated-formatted #with-term #formatted-groups.join(group-delimiter)]
  } else if formatted-groups.len() > 0 {
    formatted-groups.join(group-delimiter)
  } else {
    format-names(names, attrs, ctx)
  }

  result
}

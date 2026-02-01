// citrus - API Module
//
// Re-exports public API functions.

#import "bibliography.typ": csl-bibliography, get-cited-entries
#import "multicite.typ": multicite

// =============================================================================
// Locator Helper
// =============================================================================

/// Create a structured locator for use with cite supplement
///
/// CSL supports different locator types (page, chapter, folio, etc.).
/// This function creates a structured locator that citrus can parse.
///
/// Usage:
///   #cite(<key>, supplement: locator("chapter", "5-10"))
///   #cite(<key>, supplement: locator("folio", "101"))
///
/// For simple page locators, you can still use plain content:
///   #cite(<key>, supplement: [42])
///
/// - label: Locator type (page, chapter, section, folio, line, verse, figure, etc.)
/// - value: Locator value (page number, range, etc.)
/// Returns: Content (metadata wrapper)
#let locator(label, value) = metadata((
  _citrus-locator: true,
  label: label,
  value: value,
))

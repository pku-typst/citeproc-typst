// citrus - Number Text Helpers
//
// Shared number formatting helpers used by interpreter and compiler.

#import "../core/mod.typ": zero-pad
#import "../parsing/mod.typ": lookup-term

/// Get ordinal suffix for a number according to CSL spec
///
/// CSL ordinal priority:
/// 1. ordinal-10 through ordinal-99: last-two-digits matching (higher priority)
/// 2. ordinal-00 through ordinal-09: last-digit matching
/// 3. ordinal: generic fallback
///
/// - num: The number to get ordinal for
/// - ctx: Context with locale terms
/// - gender-form: Optional gender form ("masculine" or "feminine")
/// Returns: Ordinal suffix string
#let get-ordinal-suffix(num, ctx, gender-form: none) = {
  let abs-num = calc.abs(num)
  let last-two = calc.rem(abs-num, 100)
  let last-one = calc.rem(abs-num, 10)

  // Try ordinal-10 through ordinal-99 first (last-two-digits matching by default)
  if last-two >= 10 {
    let key = "ordinal-" + zero-pad(last-two, 2)
    let suffix = lookup-term(ctx, key, form: "long", plural: false)
    if suffix != none and suffix != "" and suffix != key {
      return suffix
    }
  }

  // Try ordinal-00 through ordinal-09 (last-digit matching by default)
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
  if generic != none { generic } else { "" }
}

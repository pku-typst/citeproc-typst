// citrus - Compiler Runtime Helpers

#import "../../data/conditions.typ": eval-condition

#import "names.typ": (
  format-names-compiled, format-names-multi-compiled,
  format-names-single-compiled, format-names-substitute-compiled,
)
#import "date.typ": format-date-compiled
#import "number.typ": (
  format-number-compiled, format-number-long-ordinal-compiled,
  format-number-numeric-compiled, format-number-ordinal-compiled,
  format-number-roman-compiled,
)
#import "label.typ": format-label-compiled
#import "text.typ": format-text-content, format-text-value, get-text-variable
#import "term.typ": get-term-compiled
#import "conditions.typ": has-variable

#import "../../core/mod.typ": finalize, is-empty
#import "../../data/variables.typ": get-variable
#import "../../parsing/mod.typ": lookup-term

/// All helpers bundled for passing to eval()
#let compiler-helpers = (
  format-names: format-names-compiled,
  format-names-single: format-names-single-compiled,
  format-names-multi: format-names-multi-compiled,
  format-names-substitute: format-names-substitute-compiled,
  format-date: format-date-compiled,
  format-number: format-number-compiled,
  format-number-numeric: format-number-numeric-compiled,
  format-number-ordinal: format-number-ordinal-compiled,
  format-number-long-ordinal: format-number-long-ordinal-compiled,
  format-number-roman: format-number-roman-compiled,
  format-label: format-label-compiled,
  get-text-variable: get-text-variable,
  format-text-content: format-text-content,
  format-text-value: format-text-value,
  get-term: get-term-compiled,
  has-variable: has-variable,
  get-variable: get-variable,
  eval-condition: eval-condition,
  finalize: finalize,
  is-empty: is-empty,
  lookup-term: lookup-term,
)

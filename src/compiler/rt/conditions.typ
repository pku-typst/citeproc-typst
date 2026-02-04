// citrus - Compiler Runtime: Conditions

#import "../../data/variables.typ": get-variable

/// Check if a variable has a non-empty value
#let has-variable(ctx, var-name) = {
  get-variable(ctx, var-name) != ""
}

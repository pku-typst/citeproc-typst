// citrus - Compiler Runtime: Term

#import "../../core/mod.typ": finalize
#import "../../parsing/mod.typ": lookup-term

/// Get term value
#let get-term-compiled(ctx, attrs) = {
  let term-name = attrs.at("term", default: "")
  let form = attrs.at("form", default: "long")
  let plural = attrs.at("plural", default: "false") == "true"

  let term = lookup-term(ctx, term-name, form: form, plural: plural)
  if term != none {
    (finalize(term, attrs), "none", ())
  } else {
    ([], "none", ())
  }
}

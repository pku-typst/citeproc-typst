// Regression tests for compiler runtime date behavior.

#import "/src/compiler/rt/date.typ": format-date-compiled
#import "/src/output/helpers.typ": content-to-string

#let year-part = ((tag: "date-part", attrs: (name: "year"), children: ()),)

// A missing date variable must not consume the implicit year-suffix. Chicago's
// date-in-text macro probes original-date before issued, so marking suffix done
// for the empty original-date would suppress the suffix on the actual year.
#let base-ctx = (
  fields: (year: "2015"),
  done-vars: (),
  year-suffix: "a",
  has-explicit-year-suffix: false,
)

#let missing-original = format-date-compiled(
  base-ctx,
  (variable: "original-date"),
  year-part,
)
#assert.eq(missing-original.at(1), "no-var")
#assert.eq(missing-original.at(2), ())

#let issued-ctx = (
  ..base-ctx,
  done-vars: missing-original.at(2),
  year-suffix-done: "__year-suffix-done" in missing-original.at(2),
)
#let issued = format-date-compiled(issued-ctx, (variable: "issued"), year-part)
#assert.eq(content-to-string(issued.at(0)), "2015a")
#assert.eq(issued.at(2), ("__year-suffix-done",))

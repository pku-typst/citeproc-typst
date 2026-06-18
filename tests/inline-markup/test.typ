// Unit tests for CSL-JSON HTML-like inline markup parsing.

#import "/src/text/markup.typ": (
  has-inline-markup,
  parse-inline-markup,
  prepare-inline-markup,
  render-inline-markup,
  strip-inline-markup,
)

#let first-node(source) = parse-inline-markup(source).first()

// Recognize citeproc-js-compatible span variants, but canonicalize them into
// the same small internal tag vocabulary used by the renderer.
#let nocase-node = first-node("<span data-kind=\"x\" class = 'foo nocase bar'>Smith</span>")
#assert.eq(has-inline-markup("<span data-kind=\"x\" class = 'foo nocase bar'>Smith</span>"), true)
#assert.eq(nocase-node.at("tag", default: ""), "nocase")
#assert.eq(nocase-node.at("children", default: ((kind: "text", text: ""),)).first().text, "Smith")
#assert.eq(strip-inline-markup("<span data-kind=\"x\" class = 'foo nocase bar'>Smith</span>"), "Smith")

#let smallcaps-node = first-node("<span title=\"x\" style='color: red; font-variant : small-caps; font-weight: bold'>Guide</span>")
#assert.eq(smallcaps-node.at("attr", default: ""), "font-variant")
#assert.eq(smallcaps-node.at("value", default: ""), "small-caps")
#assert.eq(smallcaps-node.at("children", default: ((kind: "text", text: ""),)).first().text, "Guide")

// Unsupported span markup stays literal, matching citeproc-js docs.
#let unsupported = "A <span data-kind=\"x\">literal</span> B"
#assert.eq(strip-inline-markup(unsupported), unsupported)

// citeproc-js protects nocase, small-caps, sc, sup, and sub from text-case, but
// not ordinary italic or bold tags.
#let cased = prepare-inline-markup(
  "one <span class=\"nocase\">Two</span> <i>three</i> <sc>Four</sc>",
  (text-case: "uppercase"),
  (:),
  case-func: (plain, attrs, ctx) => upper(plain),
)
#assert.eq(cased.at(0).text, "ONE ")
#assert.eq(cased.at(1).children.first().text, "Two")
#assert.eq(cased.at(3).children.first().text, "THREE")
#assert.eq(cased.at(5).children.first().text, "Four")

// nodecor is a citeproc-js compatibility tag used to neutralize inherited
// font-style/font-weight/font-variant decorations.
#let nodecor-node = first-node("<span class=\"nodecor\">v.</span>")
#assert.eq(nodecor-node.at("tag", default: ""), "nodecor")
#assert.eq(nodecor-node.at("children", default: ((kind: "text", text: ""),)).first().text, "v.")

// Rendering nodecor must be valid when outer formatting is inherited.
#render-inline-markup(
  "Lessard <span class=\"nodecor\">v.</span> Schmidt",
  attrs: ("font-style": "italic"),
  output-target: "paged",
)

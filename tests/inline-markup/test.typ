// Unit tests for CSL-JSON HTML-like inline markup parsing.

#import "/src/text/markup.typ": (
  has-inline-markup, parse-inline-markup, prepare-inline-markup,
  render-inline-markup, should-defer-inline-value, strip-inline-markup,
)
#import "/src/text/quotes.typ": transform-quotes-at-level
#import "/src/compiler/rt/text.typ": (
  _format-inline-text as compiled-format-inline-text, get-text-variable-raw,
)
#import "/src/interpreter/stack.typ": (
  _format-inline-text as interpreted-format-inline-text,
)
#import "/src/output/citation.typ": _prepare-layout-inline-content
#import "/src/output/helpers.typ": content-to-string

#let first-node(source) = parse-inline-markup(source).first()

// Recognize citeproc-js-compatible span variants, but canonicalize them into
// the same small internal tag vocabulary used by the renderer.
#let nocase-node = first-node(
  "<span data-kind=\"x\" class = 'foo nocase bar'>Smith</span>",
)
#assert.eq(
  has-inline-markup(
    "<span data-kind=\"x\" class = 'foo nocase bar'>Smith</span>",
  ),
  true,
)
#assert.eq(nocase-node.at("tag", default: ""), "nocase")
#assert.eq(
  nocase-node.at("children", default: ((kind: "text", text: ""),)).first().text,
  "Smith",
)
#assert.eq(
  strip-inline-markup(
    "<span data-kind=\"x\" class = 'foo nocase bar'>Smith</span>",
  ),
  "Smith",
)

#let smallcaps-node = first-node(
  "<span title=\"x\" style='color: red; font-variant : small-caps; font-weight: bold'>Guide</span>",
)
#assert.eq(smallcaps-node.at("attr", default: ""), "font-variant")
#assert.eq(smallcaps-node.at("value", default: ""), "small-caps")
#assert.eq(
  smallcaps-node
    .at("children", default: ((kind: "text", text: ""),))
    .first()
    .text,
  "Guide",
)

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

// citeproc-js-compatible inline tags protect their contents from quote
// normalization.
#let quote-ctx = (style: (default-locale: "en-US"))
#let quoted-inline = prepare-inline-markup(
  "<i>'quoted'</i>",
  (:),
  quote-ctx,
  quote-func: transform-quotes-at-level,
)
#assert.eq(quoted-inline.first().children.first().text, "'quoted'")

// Compiler raw text fast path should normalize quotes even when inline markup
// takes the rendering branch.
#let raw-quote-ctx = (
  fields: (title: "'quoted' <span class=\"nocase\">title</span>"),
  entry-type: "article",
  style: (default-locale: "en-US"),
  quote-level: 0,
)
#let raw-quoted = get-text-variable-raw(
  raw-quote-ctx,
  (variable: "title"),
  (var: "title", form: "long"),
)
#assert.eq(raw-quoted.at(0), "\u{201C}quoted\u{201D} title")

// Formatting attrs that apply in finalize() should force inline value rendering
// instead of deferring raw HTML-ish strings.
#assert.eq(
  should-defer-inline-value((
    value: "<i>underlined</i>",
    text-decoration: "underline",
  )),
  false,
)
#assert.eq(
  should-defer-inline-value((
    value: "<i>displayed</i>",
    display: "block",
  )),
  false,
)

// Inline text follows punctuation-in-quote just like non-inline text paths.
#let piq-ctx = (
  style: (
    locale: (options: (punctuation-in-quote: true)),
    default-locale: "en-US",
  ),
)
#let (interpreted-piq, _) = interpreted-format-inline-text(
  "Title <span class=\"nocase\">X</span>",
  (quotes: "true", suffix: "."),
  piq-ctx,
  0,
  true,
)
#assert.eq(content-to-string(interpreted-piq), "\u{201C}Title X.\u{201D}")
#let (compiled-piq, _) = compiled-format-inline-text(
  "Title <span class=\"nocase\">X</span>",
  (quotes: "true", suffix: "."),
  piq-ctx,
  0,
  true,
)
#assert.eq(content-to-string(compiled-piq), "\u{201C}Title X.\u{201D}")

// nodecor is a citeproc-js compatibility tag used to neutralize inherited
// font-style/font-weight/font-variant decorations.
#let nodecor-node = first-node("<span class=\"nodecor\">v.</span>")
#assert.eq(nodecor-node.at("tag", default: ""), "nodecor")
#assert.eq(
  nodecor-node
    .at("children", default: ((kind: "text", text: ""),))
    .first()
    .text,
  "v.",
)

// Rendering nodecor must be valid when outer formatting is inherited.
#render-inline-markup(
  "Lessard <span class=\"nodecor\">v.</span> Schmidt",
  attrs: ("font-style": "italic"),
  output-target: "paged",
)

// Layout-level inline rendering should preserve existing content wrappers.
#let layout-prepared = _prepare-layout-inline-content(
  strong("A <span class=\"nocase\">x</span>"),
  (:),
)
#assert.eq(layout-prepared.func(), strong)
#assert.eq(content-to-string(layout-prepared), "A x")

// citeproc: English Documentation & Example
//
// This document demonstrates the features of citeproc
// using the Chicago Manual of Style (Full Note with Bibliography).

#import "../lib.typ": csl-bibliography, init-csl, multicite

#set page(margin: 2.5cm)
#set text(font: "Times New Roman", size: 11pt)
#set par(justify: true, leading: 0.8em)
#set heading(numbering: "1.")

#show heading.where(level: 1): set text(size: 14pt)
#show heading.where(level: 2): set text(size: 12pt)

#show: init-csl.with(
  read("refs-en.bib"),
  read("chicago-fullnote-bibliography.csl"),
)

#align(center)[
  #text(size: 18pt, weight: "bold")[citeproc]
  #v(0.3em)
  #text(size: 12pt)[CSL Processor for Typst]
  #v(1em)
]

= Introduction

*citeproc* is a Citation Style Language (CSL) processor for Typst. It allows you to use standard CSL style files—the same format used by Zotero, Mendeley, and thousands of other citation managers—to format citations and bibliographies in your Typst documents.

This document serves as both documentation and a working example. It uses the Chicago Manual of Style (Full Note with Bibliography) format.

= Basic Citations

To cite a source, use the standard Typst citation syntax with `@key`. For example, @kopka2004latex provides an excellent guide to LaTeX, while @knuth1984texbook remains the definitive reference for TeX.

Citations can appear in different contexts:
- In running text: The seminal work by @einstein1905photoelectric revolutionized physics.
- In parenthetical form: This has been studied extensively (see @darwin1859origin).
- With page numbers: As noted by @kopka2004latex[Chapter 5], tables are essential.

= Multiple Citations

When citing multiple sources, use the `multicite` function:

#multicite("smith2020climate", "smith2020policy", "kopka2004latex")

You can also add page numbers to individual citations:

#multicite(
  (key: "smith2020climate", supplement: [pp. 206--208]),
  "smith2020policy",
  (key: "kopka2004latex", supplement: [Ch. 3]),
)

= Citation Collapsing

For numeric and author-date styles, citeproc supports automatic collapsing:

- `citation-number`: Collapse consecutive numeric citations (e.g., `[1-4]`)
- `year`: Collapse same-author citations by year
- `year-suffix`: Collapse same-author-year citations (e.g., "Smith, 2020a, b, c")
- `year-suffix-ranged`: Collapse with ranges (e.g., "Smith, 2020a-c")

Note: This Chicago footnote style renders citations as footnotes (see below). Collapsing is more relevant for numeric styles like GB/T 7714—see the Chinese example.

= Citation Forms

The library supports different citation forms:

- *Default* (superscript for note styles): @jones2019thesis
- *Prose* (inline): #cite(<vaswani2017attention>, form: "prose")
- *Author only*: #cite(<einstein1905photoelectric>, form: "author")
- *Year only*: #cite(<darwin1859origin>, form: "year")

= Year Disambiguation

When the same author has multiple publications in the same year, citeproc automatically adds letter suffixes for disambiguation:

- First Smith 2020 paper: @smith2020climate
- Second Smith 2020 paper: @smith2020policy

The bibliography will show these as "2020a" and "2020b" respectively.

= Subsequent Citations and Ibid

Note styles automatically use shortened forms for repeated citations:

- First citation to Smith: @smith2020climate
- Citation to different source: @kopka2004latex
- Subsequent citation to Smith: @smith2020climate[p. 42]
- Immediate repeat (ibid): @smith2020climate[p. 50]

The CSL style controls whether "Ibid." is used for immediate repeats.

= Supported Entry Types

The library handles various entry types:

- *Journal articles*: @smith2020climate, @einstein1905photoelectric
- *Books*: @kopka2004latex, @knuth1984texbook, @darwin1859origin
- *Theses*: @jones2019thesis
- *Conference papers*: @vaswani2017attention
- *Web resources*: @typst2024docs

== Entry Types Requiring `mark` Field

Some BibTeX types (like `@standard`, `@newspaper`, `@legislation`) are not recognized by citegeist. For these, use `@misc` with a `mark` field:

```bib
@misc{iso690,
  mark      = {S},
  title     = {Information and documentation — Guidelines for bibliographic references},
  number    = {ISO 690:2021},
  year      = {2021},
}
```

Common mark codes: `S`=Standard, `N`=Newspaper, `LEGISLATION`=Legislation, `LEGAL_CASE`=Legal case.

Note: Use `@online` instead of `@webpage` — citegeist supports `@online` but not `@webpage`.

= Custom Rendering

The `csl-bibliography` function accepts a `full-control` parameter for completely custom bibliography rendering:

```typst
#csl-bibliography(full-control: entries => {
  for e in entries [
    [#e.order] #e.rendered-body #e.ref-label
  ]
})
```

Each entry object provides:
- `key`, `order`, `year-suffix`, `lang`, `entry-type`
- `fields`, `parsed-names`
- `rendered` (full CSL output), `rendered-body` (without citation number)
- `ref-label` (for linking), `labeled-rendered` (rendered + label)

= Bibliography

#csl-bibliography()

# citeproc-typst

A CSL (Citation Style Language) processor for Typst.

Use standard CSL style files — the same format used by Zotero, Mendeley, and thousands of citation managers — to format your citations and bibliographies in Typst.

## Installation

```typst
#import "@preview/citeproc-typst:0.1.0": init-csl, csl-bibliography
```

## Quick Start

```typst
#import "@preview/citeproc-typst:0.1.0": init-csl, csl-bibliography

#show: init-csl.with(
  read("references.bib"),
  read("style.csl"),
)

As demonstrated by @smith2020, this approach works well.

#csl-bibliography()
```

## Features

- **Standard CSL support** — Parse and render using CSL 1.0.2 style files
- **CSL-M extensions** — Multilingual layouts, institutional authors, legal citations
- **BibTeX input** — Use your existing `.bib` files via [citegeist](https://typst.app/universe/package/citegeist/)
- **CSL-JSON input** — Native CSL-JSON format for lossless data transfer
- **Bilingual support** — Automatic language detection for mixed Chinese/English bibliographies
- **Citation styles** — Numeric, author-date, and note styles (footnotes auto-generated)
- **Year disambiguation** — Automatic a/b/c suffixes for same-author-same-year entries
- **Citation collapsing** — Numeric ranges `[1-4]`, year-suffix `(Smith, 2020a, b)`
- **Multiple citations** — Combine citations with `multicite()`
- **Full formatting** — Italics, bold, small-caps, text-case, and more

## Documentation

- [English Documentation](examples/example-en.typ) — Chicago style example
- [中文文档](examples/example-zh.typ) — GB/T 7714-2025 style example

## API Reference

### `init-csl`

Initialize the CSL processor with BibTeX bibliography data and style.

```typst
#show: init-csl.with(
  bib-content,      // BibTeX file content (string)
  csl-content,      // CSL style file content (string)
  locales: (:),     // Optional: external locale files
)
```

### `init-csl-json`

Initialize the CSL processor with CSL-JSON bibliography data. CSL-JSON is the native format for CSL processors — properties map directly to CSL variables, avoiding translation losses from BibTeX.

```typst
#import "@preview/citeproc-typst:0.1.0": init-csl-json, csl-bibliography

#show: init-csl-json.with(
  read("references.json"),   // CSL-JSON file content
  read("style.csl"),         // CSL style file content
  locales: (:),              // Optional: external locale files
)

As shown by @smith2023...

#csl-bibliography()
```

CSL-JSON format example:

```json
[
  {
    "id": "smith2023",
    "type": "article-journal",
    "title": "Example Article",
    "author": [{ "family": "Smith", "given": "John" }],
    "container-title": "Journal of Examples",
    "volume": "42",
    "page": "1-10",
    "issued": { "date-parts": [[2023, 5, 15]] },
    "DOI": "10.1234/example"
  }
]
```

**Advantages of CSL-JSON over BibTeX:**

- Properties map 1:1 to CSL variables (no translation needed)
- Names are pre-structured (`{"family": "...", "given": "..."}`)
- Dates use standard CSL format (`{"date-parts": [[2023, 5, 15]]}`)
- All CSL types supported directly
- Better for CSL-M extensions (`original-author`, `container-author`, etc.)

### `csl-bibliography`

Render the bibliography.

```typst
#csl-bibliography()

// Custom title:
#csl-bibliography(title: heading(level: 2)[References])

// Full custom rendering:
#csl-bibliography(full-control: entries => {
  for e in entries [
    [#e.order] #e.rendered-body #e.ref-label
    #parbreak()
  ]
})
```

### `get-cited-entries`

Low-level API for complete control over bibliography rendering.

```typst
context {
  let entries = get-cited-entries()
  for e in entries {
    // Each entry provides:
    // - key, order, year-suffix, lang, entry-type
    // - fields, parsed-names
    // - rendered (full), rendered-body (without number)
    // - ref-label, labeled-rendered
  }
}
```

### `multicite`

Combine multiple citations.

```typst
#multicite("smith2020", "jones2021", "wang2022")

// With page numbers:
#multicite(
  (key: "smith2020", supplement: [p. 42]),
  "jones2021",
)
```

## Supported CSL Elements

| Element    | Status | Element        | Status |
| ---------- | ------ | -------------- | ------ |
| `<text>`   | ✅     | `<group>`      | ✅     |
| `<choose>` | ✅     | `<names>`      | ✅     |
| `<name>`   | ✅     | `<date>`       | ✅     |
| `<number>` | ✅     | `<label>`      | ✅     |
| `<sort>`   | ✅     | `<substitute>` | ✅     |

## CSL-M Support

This library includes support for key CSL-M (CSL Multilingual) extensions:

| Feature               | Description                                                    |
| --------------------- | -------------------------------------------------------------- |
| **Multiple layouts**  | `<layout locale="en es de">` for language-specific formatting  |
| **cs:institution**    | Institutional author handling with subunit parsing             |
| **cs:conditions**     | Nested condition groups with `match="any/all/nand"`            |
| **Legal types**       | `legal_case`, `legislation`, `regulation`, `hearing`, `treaty` |
| **Legal variables**   | `authority`, `jurisdiction`, `country`, `hereinafter`          |
| **Date conditions**   | `has-day`, `has-year-only`, `has-to-month-or-season`           |
| **Context condition** | `context="citation"` or `context="bibliography"`               |
| **Locale matching**   | Prefix matching: `en` matches `en-US`, `en-GB`, etc.           |
| **suppress-min/max**  | Suppress names by count, or separate personal/institutional    |
| **require/reject**    | `require="comma-safe"` for locator punctuation safety          |

### Built-in Locales

10 languages with automatic fallback:
`en-US`, `zh-CN`, `zh-TW`, `de-DE`, `fr-FR`, `es-ES`, `ja-JP`, `ko-KR`, `pt-BR`, `ru-RU`

## Entry Type Handling

This library uses [citegeist](https://typst.app/universe/package/citegeist/) to parse BibTeX files. Most standard entry types are supported, but some extended types are not recognized by citegeist.

### Supported Types (auto-detected)

`article`, `book`, `booklet`, `inbook`, `incollection`, `inproceedings`, `conference`, `manual`, `mastersthesis`, `phdthesis`, `proceedings`, `techreport`, `unpublished`, `misc`, `online`, `patent`, `thesis`, `report`, `dataset`, `software`, `periodical`, `collection`

### Unsupported Types (require `mark` field)

For types not recognized by citegeist, use `@misc` with a `mark` field:

| Type        | Mark          | Notes                       |
| ----------- | ------------- | --------------------------- |
| Standard    | `S`           | `@standard` not recognized  |
| Newspaper   | `N`           | `@newspaper` not recognized |
| Legislation | `LEGISLATION` | CSL-M legal type            |
| Legal case  | `LEGAL_CASE`  | CSL-M legal type            |
| Regulation  | `REGULATION`  | CSL-M legal type            |

Note: Use `@online` instead of `@webpage` — citegeist supports `@online` but not `@webpage`.

Example:

```bib
@misc{gb7714,
  mark      = {S},
  title     = {Information and documentation — Rules for bibliographic references},
  number    = {GB/T 7714—2015},
  publisher = {Standards Press of China},
  year      = {2015},
}
```

The `mark` field follows GB/T 7714 document type codes:

- `M` — Book, `C` — Conference, `N` — Newspaper, `J` — Journal
- `D` — Thesis, `R` — Report, `S` — Standard, `P` — Patent
- `G` — Collection, `EB` — Electronic resource, `DB` — Database
- `A` — Analytic (chapter), `Z` — Other

## Known Limitations

### Bilingual Styles (CSL-M `original-*` variables)

Some Chinese citation styles (e.g., "原子核物理评论") require bilingual output with both Chinese and English metadata. These styles use CSL-M extension variables like `original-author`, `original-title` which map to BibTeX fields with `-en` suffix (`author-en`, `title-en`, etc.).

**Current status:**

| Variable                                                                                       | CSL-JSON | BibTeX |
| ---------------------------------------------------------------------------------------------- | -------- | ------ |
| `original-title`, `original-container-title`, `original-publisher`, `original-publisher-place` | ✅       | ✅     |
| `original-author`, `original-editor`                                                           | ✅       | ❌     |
| `display="block"` attribute                                                                    | ✅       | ✅     |

**BibTeX limitation:** `original-author` and `original-editor` require citegeist to parse `author-en`/`editor-en` fields into `parsed_names`. Use CSL-JSON input for full bilingual name support.

## Related Projects

- [citegeist](https://typst.app/universe/package/citegeist/) — BibTeX parser for Typst
- [CSL Styles Repository](https://github.com/citation-style-language/styles) — Thousands of CSL styles
- [Zotero Chinese Styles](https://github.com/zotero-chinese/styles) — Chinese CSL styles

## License

MIT

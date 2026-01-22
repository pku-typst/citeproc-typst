// Test CSL-JSON input support
// This test verifies that CSL-JSON entries are correctly parsed and rendered

#import "../lib.typ": csl-bibliography, init-csl-json

// CSL-JSON test data (inline)
#let test-json = `[
  {
    "id": "smith2023",
    "type": "article-journal",
    "title": "A Study of CSL-JSON Processing",
    "author": [
      {"family": "Smith", "given": "John"},
      {"family": "Doe", "given": "Jane"}
    ],
    "container-title": "Journal of Citation Styles",
    "volume": "42",
    "issue": "3",
    "page": "123-145",
    "issued": {"date-parts": [[2023, 5, 15]]},
    "DOI": "10.1234/example.2023"
  },
  {
    "id": "johnson2022book",
    "type": "book",
    "title": "The Complete Guide to Bibliography Management",
    "author": [
      {"family": "Johnson", "given": "Alice", "suffix": "Jr."}
    ],
    "publisher": "Academic Press",
    "publisher-place": "New York",
    "issued": {"date-parts": [[2022]]},
    "ISBN": "978-1-234567-89-0"
  },
  {
    "id": "chen2024chapter",
    "type": "chapter",
    "title": "CSL-M Extensions for Legal Citations",
    "author": [
      {"family": "Chen", "given": "Wei"}
    ],
    "container-title": "Handbook of Legal Technology",
    "container-author": [
      {"family": "Williams", "given": "Robert"}
    ],
    "publisher": "Law Press",
    "publisher-place": "Boston",
    "page": "45-78",
    "issued": {"date-parts": [[2024, 1]]}
  },
  {
    "id": "garcia2021",
    "type": "paper-conference",
    "title": "Machine Learning in Citation Analysis",
    "author": [
      {"family": "Garcia", "given": "Maria"},
      {"family": "Lee", "given": "Sung-Ho"}
    ],
    "event-title": "International Conference on Digital Libraries",
    "publisher": "IEEE",
    "page": "201-210",
    "issued": {"date-parts": [[2021, 9, 5]]},
    "DOI": "10.5678/icdl.2021.paper42"
  },
  {
    "id": "王明2023",
    "type": "article-journal",
    "title": "中文文献的CSL处理",
    "author": [
      {"family": "王", "given": "明"}
    ],
    "container-title": "信息技术期刊",
    "volume": "15",
    "issue": "2",
    "page": "88-96",
    "issued": {"date-parts": [[2023]]},
    "language": "zh-CN"
  }
]`.text

#show: init-csl-json.with(
  test-json,
  read("../examples/chicago-fullnote-bibliography.csl"),
)

= CSL-JSON Input Test

== Article Citation

Smith and Doe wrote about CSL-JSON processing @smith2023.

== Book Citation

Johnson's book is a comprehensive guide @johnson2022book.

== Chapter Citation

Chen discussed CSL-M extensions @chen2024chapter.

== Conference Paper

Garcia and Lee presented on machine learning @garcia2021.

== Chinese Entry

关于中文文献的处理 @王明2023。

== Multiple Citations

See @smith2023 and @johnson2022book for more details.

== Bibliography

#csl-bibliography()

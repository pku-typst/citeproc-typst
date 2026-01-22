// Test CSL-JSON with numeric style (GB7714)
#import "../lib.typ": csl-bibliography, init-csl-json

#let test-json = `[
  {
    "id": "article1",
    "type": "article-journal",
    "title": "Testing CSL-JSON Support",
    "author": [{"family": "Zhang", "given": "San"}],
    "container-title": "Journal of Testing",
    "volume": "10",
    "page": "1-10",
    "issued": {"date-parts": [[2024]]}
  },
  {
    "id": "book1",
    "type": "book",
    "title": "A Test Book",
    "author": [{"family": "Li", "given": "Si"}],
    "publisher": "Test Press",
    "publisher-place": "Beijing",
    "issued": {"date-parts": [[2023]]}
  }
]`.text

#show: init-csl-json.with(
  test-json,
  read("../examples/gb7714-2025-numeric.csl"),
)

= CSL-JSON Numeric Test

Article @article1 and book @book1.

#csl-bibliography()

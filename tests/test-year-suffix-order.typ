// Test year-suffix ordering according to CSL specification
//
// CSL Spec: "The assignment of year-suffixes follows the order of the bibliographies entries"
//
// This test verifies that year-suffixes are assigned according to bibliography order,
// not by title alphabetical order.

#import "../lib.typ": csl-bibliography, init-csl, multicite

// ============================================================================
// TEST 1: Author-date style with bibliography sorted by citation order
// ============================================================================
// This clearly shows the bug: suffixes should follow citation order,
// but current implementation uses title order instead.

#let test-csl-citation-order = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info>
    <title>Test Year Suffix - Citation Order</title>
    <id>test-year-suffix-citation-order</id>
  </info>
  <citation disambiguate-add-year-suffix="true">
    <layout prefix="(" suffix=")" delimiter="; ">
      <group delimiter=", ">
        <names variable="author">
          <name form="short"/>
        </names>
        <group>
          <date variable="issued">
            <date-part name="year"/>
          </date>
          <text variable="year-suffix"/>
        </group>
      </group>
    </layout>
  </citation>
  <bibliography>
    <sort>
      <key variable="citation-number"/>
    </sort>
    <layout suffix=".">
      <group delimiter=". ">
        <names variable="author">
          <name name-as-sort-order="all"/>
        </names>
        <group>
          <date variable="issued">
            <date-part name="year"/>
          </date>
          <text variable="year-suffix"/>
        </group>
        <text variable="title"/>
      </group>
    </layout>
  </bibliography>
</style>
```.text

// Test entries: Same author, same year, different titles
// Title alphabetical order: "Alpha" < "Beta" < "Gamma"
// Citation order in this test: Gamma, Alpha, Beta
//
// EXPECTED (per CSL spec): suffixes by bibliography order (= citation order here)
//   Gamma → a (cited first)
//   Alpha → b (cited second)
//   Beta  → c (cited third)
//
// BUG (current): suffixes by title alphabetical order
//   Alpha → a
//   Beta  → b
//   Gamma → c
#let test-bib = ```bib
@article{doe2020gamma,
  author = {Doe, John},
  title = {Gamma: Third in Alphabet but Cited First},
  journal = {Journal A},
  year = {2020},
}

@article{doe2020alpha,
  author = {Doe, John},
  title = {Alpha: First in Alphabet but Cited Second},
  journal = {Journal B},
  year = {2020},
}

@article{doe2020beta,
  author = {Doe, John},
  title = {Beta: Second in Alphabet but Cited Third},
  journal = {Journal C},
  year = {2020},
}

@article{smith2021,
  author = {Smith, Jane},
  title = {Unrelated Paper},
  journal = {Other Journal},
  year = {2021},
}
```.text

#show: init-csl.with(test-bib, test-csl-citation-order)

= Year Suffix Ordering Test

== CSL Specification

From CSL 1.0.2 Specification, section "Disambiguation":

#quote[
  The assignment of year-suffixes follows the order of the bibliographies entries
]

== Test Case

This style sorts bibliography by *citation order*. We cite in this order:

1. First cite "Gamma": @doe2020gamma
2. Second cite "Alpha": @doe2020alpha
3. Third cite "Beta": @doe2020beta
4. Unrelated: @smith2021

== Expected vs Actual

#table(
  columns: (auto, auto, auto),
  [*Entry*], [*Citation Order*], [*Expected Suffix*],
  [Gamma], [1st], [a],
  [Alpha], [2nd], [b],
  [Beta], [3rd], [c],
)

== Verification

Citing again to verify suffixes assigned correctly:
- Gamma: @doe2020gamma (should be 2020a)
- Alpha: @doe2020alpha (should be 2020b)
- Beta: @doe2020beta (should be 2020c)

== Bibliography

#csl-bibliography()

#pagebreak()

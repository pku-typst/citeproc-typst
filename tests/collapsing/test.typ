// Test citation collapsing functionality

#import "/lib.typ": csl-bibliography, init-csl, multicite

// Simple test CSL with collapse="citation-number"
#let test-csl-numeric = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info>
    <title>Test Numeric with Collapse</title>
    <id>test-numeric-collapse</id>
  </info>
  <citation collapse="citation-number">
    <sort>
      <key variable="citation-number"/>
    </sort>
    <layout prefix="[" suffix="]" delimiter=", ">
      <text variable="citation-number"/>
    </layout>
  </citation>
  <bibliography>
    <layout>
      <text variable="citation-number" prefix="[" suffix="] "/>
      <text variable="title"/>
    </layout>
  </bibliography>
</style>
```.text

// Simple test bib
#let test-bib = ```bib
@article{ref1,
  title = {First Reference},
  author = {Smith, John},
  year = {2020},
}
@article{ref2,
  title = {Second Reference},
  author = {Jones, Mary},
  year = {2021},
}
@article{ref3,
  title = {Third Reference},
  author = {Brown, Robert},
  year = {2022},
}
@article{ref4,
  title = {Fourth Reference},
  author = {Davis, Alice},
  year = {2023},
}
@article{ref5,
  title = {Fifth Reference},
  author = {Wilson, Bob},
  year = {2024},
}
@article{ref6,
  title = {Sixth Reference},
  author = {Taylor, Carol},
  year = {2025},
}
```.text

#show: init-csl.with(test-bib, test-csl-numeric)

= Citation Collapsing Test

== Numeric Range Collapsing

Individual citations: @ref1, @ref2, @ref3

Multiple citations (should collapse [1-3]): #multicite("ref1", "ref2", "ref3")

// Note: ref4 is cited here first, gets number 4
// ref5 is cited later in "All six", gets number 5
Gap test - cite ref1, ref2, ref3, then skip ref4, cite ref5:

First cite ref4 here: @ref4

Now cite ref1-3, ref5 (should be [1-3, 5]): #multicite("ref1", "ref2", "ref3", "ref5")

Multiple with supplements (should NOT collapse): #multicite(
  (key: "ref1", supplement: "p. 10"),
  "ref2",
  "ref3",
)

All six (should collapse [1-6]): #multicite("ref1", "ref2", "ref3", "ref4", "ref5", "ref6")

#csl-bibliography()

// Test author-date citation collapsing functionality

#import "../lib.typ": csl-bibliography, init-csl, multicite

// Author-date style with year-suffix collapse
#let test-csl-authordate = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info>
    <title>Test Author-Date with Collapse</title>
    <id>test-authordate-collapse</id>
  </info>
  <citation collapse="year-suffix" disambiguate-add-year-suffix="true">
    <layout prefix="(" suffix=")" delimiter="; ">
      <group delimiter=", ">
        <names variable="author">
          <name form="short"/>
        </names>
        <date variable="issued">
          <date-part name="year"/>
        </date>
      </group>
    </layout>
  </citation>
  <bibliography>
    <layout>
      <group delimiter=". ">
        <names variable="author">
          <name/>
        </names>
        <date variable="issued" prefix="(" suffix=")">
          <date-part name="year"/>
        </date>
        <text variable="title"/>
      </group>
    </layout>
  </bibliography>
</style>
```.text

// Bib with same author, different years
#let test-bib-authordate = ```bib
@article{smith2020a,
  title = {First Work by Smith},
  author = {Smith, John},
  year = {2020},
}
@article{smith2020b,
  title = {Second Work by Smith},
  author = {Smith, John},
  year = {2020},
}
@article{smith2020c,
  title = {Third Work by Smith},
  author = {Smith, John},
  year = {2020},
}
@article{smith2021,
  title = {Fourth Work by Smith},
  author = {Smith, John},
  year = {2021},
}
@article{jones2020,
  title = {Work by Jones},
  author = {Jones, Mary},
  year = {2020},
}
```.text

#show: init-csl.with(test-bib-authordate, test-csl-authordate)

= Author-Date Collapsing Test

== Year Suffix Collapsing

First cite: @smith2020a

Second cite (same author/year, should get 'b'): @smith2020b

Third cite: @smith2020c

Multiple by Smith 2020 (should collapse "Smith, 2020a, b, c"): #multicite("smith2020a", "smith2020b", "smith2020c")

Multiple by Smith different years (should be "Smith, 2020a, 2021"): #multicite("smith2020a", "smith2021")

Mixed authors (should be "Smith, 2020a; Jones, 2020"): #multicite("smith2020a", "jones2020")

#csl-bibliography()

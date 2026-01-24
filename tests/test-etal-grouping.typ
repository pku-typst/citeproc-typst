// Test that "Doe" and "Doe et al." are grouped separately
//
// CSL spec: "The comparison is limited to the output of the (first) cs:names element"

#import "../lib.typ": csl-bibliography, init-csl, multicite

// Style with et-al settings: 3+ authors become "First et al."
#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info>
    <title>Test Et Al Grouping</title>
    <id>test-etal-grouping</id>
  </info>
  <citation cite-group-delimiter=", " collapse="year">
    <layout prefix="(" suffix=")" delimiter="; ">
      <group delimiter=", ">
        <names variable="author">
          <name form="short" and="symbol" et-al-min="3" et-al-use-first="1"/>
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
        <names variable="author"><name/></names>
        <date variable="issued" prefix="(" suffix=")"><date-part name="year"/></date>
        <text variable="title"/>
      </group>
    </layout>
  </bibliography>
</style>
```.text

#let test-bib = ```bib
@article{doe2000,
  author = {Doe, John},
  title = {Solo Paper},
  year = {2000},
}
@article{smith2001,
  author = {Smith, Jane and Brown, Bob and White, Carol},
  title = {Team Paper},
  year = {2001},
}
@article{doe2002,
  author = {Doe, John},
  title = {Another Solo},
  year = {2002},
}
@article{smith2003,
  author = {Smith, Jane and Brown, Bob and White, Carol},
  title = {Another Team},
  year = {2003},
}
```.text

#show: init-csl.with(test-bib, test-csl)

= Rendered Names Grouping Test

== "Doe" vs "Smith et al." - Different Groups

CSL spec: "The comparison is limited to the output of the (first) cs:names element"

Citation order: Doe 2000, Smith et al. 2001, Doe 2002, Smith et al. 2003

Expected: "(Doe, 2000, 2002; Smith et al., 2001, 2003)"
- "Doe" (1 author) grouped separately from "Smith et al." (3 authors)

Actual: #multicite("doe2000", "smith2001", "doe2002", "smith2003")

#csl-bibliography()

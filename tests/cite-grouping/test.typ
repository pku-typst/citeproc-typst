// Test cite-group-delimiter with collapse="year"
//
// CSL spec: When collapse is set, cites with identical names are grouped
// and the repeated name is suppressed (collapsed).

#import "/lib.typ": csl-bibliography, init-csl, multicite

// Style with cite-group-delimiter AND collapse="year"
#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info>
    <title>Test Cite Grouping Only</title>
    <id>test-cite-grouping</id>
  </info>
  <citation cite-group-delimiter=", " collapse="year" disambiguate-add-year-suffix="true">
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
    <layout>
      <group delimiter=". ">
        <names variable="author"><name/></names>
        <group prefix="(" suffix=")">
          <date variable="issued"><date-part name="year"/></date>
          <text variable="year-suffix"/>
        </group>
        <text variable="title"/>
      </group>
    </layout>
  </bibliography>
</style>
```.text

#let test-bib = ```bib
@article{doe1999,
  author = {Doe, John},
  title = {First Doe Paper},
  year = {1999},
}
@article{smith2002,
  author = {Smith, Jane},
  title = {Smith Paper},
  year = {2002},
}
@article{doe2006,
  author = {Doe, John},
  title = {Second Doe Paper},
  year = {2006},
}
```.text

#show: init-csl.with(test-bib, test-csl)

= Cite Grouping Test

== cite-group-delimiter With collapse="year"

CSL spec: When collapse="year" is set, cites with identical names are grouped and the repeated name is suppressed.

Citation order: Doe 1999, Doe 2006, Smith 2002

Expected: "(Doe, 1999, 2006; Smith, 2002)"
- Doe's cites grouped at first Doe position, name suppressed for second cite
- Years shown individually with cite-group-delimiter between them

Actual: #multicite[@doe1999 @doe2006 @smith2002]

#csl-bibliography()

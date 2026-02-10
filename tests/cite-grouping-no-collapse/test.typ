// Test cite-group-delimiter WITHOUT collapse
//
// CSL spec: cite-group-delimiter alone triggers grouping (adjacent placement)
// but NOT name suppression. The name is repeated for each cite in the group.

#import "/lib.typ": csl-bibliography, init-csl, multicite

// Style with cite-group-delimiter but NO collapse attribute
#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info>
    <title>Test Cite Grouping Only (No Collapse)</title>
    <id>test-cite-grouping-no-collapse</id>
  </info>
  <citation cite-group-delimiter=", " disambiguate-add-year-suffix="true">
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

= Cite Grouping Without Collapse

cite-group-delimiter alone triggers grouping (adjacent placement) but NOT name suppression.

Citation order: Doe 1999, Smith 2002, Doe 2006

Expected: "(Doe, 1999, Doe, 2006; Smith, 2002)"
- Doe's cites grouped adjacently, but name is NOT suppressed
- cite-group-delimiter ", " used between grouped cites

Actual: #multicite[@doe1999 @smith2002 @doe2006]

#csl-bibliography()

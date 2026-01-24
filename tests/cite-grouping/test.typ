// Test cite-group-delimiter triggering grouping without collapse
//
// CSL spec: "Cite grouping can be activated by setting the cite-group-delimiter
// attribute or the collapse attributes on cs:citation."

#import "/lib.typ": csl-bibliography, init-csl, multicite

// Style with cite-group-delimiter but NO collapse attribute
#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info>
    <title>Test Cite Grouping Only</title>
    <id>test-cite-grouping</id>
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

= Cite Grouping Test

== cite-group-delimiter Without collapse

CSL spec: "Cite grouping can be activated by setting the cite-group-delimiter attribute or the collapse attributes."

Citation order: Doe 1999, Smith 2002, Doe 2006

Expected: "(Doe, 1999, 2006; Smith, 2002)"
- Doe's cites should be grouped at first Doe position
- Years shown individually (no year-suffix collapsing since collapse not set)

Actual: #multicite("doe1999", "smith2002", "doe2006")

#csl-bibliography()

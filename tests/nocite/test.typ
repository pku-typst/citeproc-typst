// Test nocite: selective inclusion of uncited bibliography entries

#import "/lib.typ": csl-bibliography, init-csl, nocite

// Simple numeric CSL style
#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info>
    <title>Test Nocite</title>
    <id>test-nocite</id>
  </info>
  <citation>
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
      <group delimiter=". ">
        <names variable="author"><name/></names>
        <text variable="title"/>
        <date variable="issued"><date-part name="year"/></date>
      </group>
    </layout>
  </bibliography>
</style>
```.text

#let test-bib = ```bib
@article{cited1,
  title = {Cited First},
  author = {Smith, John},
  year = {2020},
}
@article{cited2,
  title = {Cited Second},
  author = {Jones, Mary},
  year = {2021},
}
@article{uncited1,
  title = {Uncited Via String},
  author = {Brown, Robert},
  year = {2022},
}
@article{uncited2,
  title = {Uncited Via Ref Syntax},
  author = {Davis, Alice},
  year = {2023},
}
@article{not-included,
  title = {Not Included At All},
  author = {Wilson, Bob},
  year = {2024},
}
```.text

#show: init-csl.with(test-bib, test-csl)

= Nocite Selective Test

== Cited entries

These are cited normally in-text:

First: @cited1

Second: @cited2

== Nocite entries

These are included via nocite (no visible output):

#nocite("uncited1")
#nocite[@uncited2]

== Bibliography

Should contain cited1, cited2, uncited1, uncited2 — but NOT not-included.

#csl-bibliography()

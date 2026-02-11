// Test nocite("*"): include all bibliography entries

#import "/lib.typ": csl-bibliography, init-csl, nocite

// Simple numeric CSL style
#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info>
    <title>Test Nocite Star</title>
    <id>test-nocite-star</id>
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
@article{alpha,
  title = {Alpha Paper},
  author = {Smith, John},
  year = {2020},
}
@article{beta,
  title = {Beta Paper},
  author = {Jones, Mary},
  year = {2021},
}
@article{gamma,
  title = {Gamma Paper},
  author = {Brown, Robert},
  year = {2022},
}
@article{delta,
  title = {Delta Paper},
  author = {Davis, Alice},
  year = {2023},
}
```.text

#show: init-csl.with(test-bib, test-csl)

= Nocite Star Test

== Only one entry cited in-text

First: @alpha

== Include all entries

#nocite("*")

== Bibliography

Should contain all four entries: alpha, beta, gamma, delta.

Cited entry (alpha) retains its original order number.

#csl-bibliography()

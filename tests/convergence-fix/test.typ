// Test: Layout convergence with page settings after init-csl
// This previously caused "layout did not converge within 5 attempts" warning
// when using counter-based occurrence tracking.
// Fixed by using complex labels + selector.before(here()) instead.

#import "/lib.typ": csl-bibliography, init-csl

#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info><title>Test</title><id>test</id></info>
  <citation>
    <layout prefix="(" suffix=")" delimiter="; ">
      <group delimiter=", ">
        <names variable="author"><name form="short"/></names>
        <date variable="issued" date-parts="year" form="text"/>
      </group>
    </layout>
  </citation>
  <bibliography>
    <layout suffix=".">
      <group delimiter=". ">
        <names variable="author"><name/></names>
        <date variable="issued" prefix="(" suffix=")" date-parts="year" form="text"/>
        <text variable="title"/>
      </group>
    </layout>
  </bibliography>
</style>
```.text

#let test-bib = ```bib
@article{smith2020a,
  author = {Smith, John and Alpha, A.},
  title = {Article A},
  year = {2020},
}

@article{smith2020b,
  author = {Smith, John and Beta, B.},
  title = {Article B},
  year = {2020},
}
```.text

#show: init-csl.with(test-bib, test-csl)

= Section 1

First citation: @smith2020a

Second citation: @smith2020b

// Page settings AFTER init-csl - this used to trigger convergence issues
#set page(margin: 1cm)

= Section 2

Third citation: @smith2020a (subsequent)

#pagebreak()

= Section 3

Fourth citation: @smith2020b (subsequent)

= Bibliography

#csl-bibliography()

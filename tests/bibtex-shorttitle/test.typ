// Test: BibLaTeX shorttitle is used for title form="short"
//
// CSL-JSON stores the short title as title-short, BibLaTeX as shorttitle.
// Only title-short was read, so with BibTeX input form="short" always fell
// back to the full title.

#import "/lib.typ": csl-bibliography, init-csl

#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info><title>Test</title><id>test</id><updated>2026-01-01T00:00:00+00:00</updated></info>
  <citation>
    <layout prefix="(" suffix=")" delimiter="; ">
      <text variable="title" form="short" />
    </layout>
  </citation>
  <bibliography><layout><text variable="title" /></layout></bibliography>
</style>
```.text

#let test-bib = ```bib
@book{with-short,
  title = {Thinking Like a Lawyer: A New Introduction to Legal Reasoning},
  shorttitle = {Thinking Like a Lawyer},
  author = {Schauer, Frederick},
  date = {2012},
}
@book{without-short,
  title = {The Concept of Law},
  author = {Hart, H. L. A.},
  date = {1961},
}
```.text

#show: init-csl.with(test-bib, test-csl)

With shorttitle: @with-short // expect: (Thinking Like a Lawyer)

Without shorttitle: @without-short // expect: (The Concept of Law)

#csl-bibliography()

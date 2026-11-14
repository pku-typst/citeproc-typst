// Test: page locators follow page-range-format
//
// With page-range-format set, locators labelled "page" are formatted like the
// page variable. Other locator labels keep their digits as written, because
// page-range-format governs page ranges.

#import "/lib.typ": csl-bibliography, init-csl-json, locator

#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0" page-range-format="minimal-two">
  <info><title>Test</title><id>test</id><updated>2026-01-01T00:00:00+00:00</updated></info>
  <citation>
    <layout prefix="(" suffix=")" delimiter="; ">
      <group delimiter=", ">
        <text variable="title" />
        <text variable="page" />
        <text variable="locator" />
      </group>
    </layout>
  </citation>
  <bibliography><layout><text variable="title" /></layout></bibliography>
</style>
```.text

#let test-json = ```json
[
  {"id": "a", "type": "book", "title": "Alpha"},
  {"id": "b", "type": "article-journal", "title": "Beta", "page": "321-328"}
]
```.text

#show: init-csl-json.with(test-json, test-csl)

Page locator: @a[321-328] // expect: (Alpha, 321–28)

Paragraph locator: #cite(<a>, supplement: locator("paragraph", "321-328")) // expect: (Alpha, 321–328)

Page variable: @b // expect: (Beta, 321–28)

#csl-bibliography()

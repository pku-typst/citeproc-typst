// Test: locator ranges are not reformatted without page-range-format
//
// CSL 1.0.2: "If the attribute is not set, page ranges are rendered without
// reformatting." Locators used to be expanded unconditionally, which turned
// Bluebook-style pinpoints such as "737-38" into "737–738".

#import "/lib.typ": csl-bibliography, init-csl-json, locator

#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
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

Page locator, abbreviated: @a[737-38] // expect: (Alpha, 737–38)

Page locator, full: @a[737-738] // expect: (Alpha, 737–738)

Paragraph locator: #cite(<a>, supplement: locator("paragraph", "12-5")) // expect: (Alpha, 12–5)

Page variable: @b // expect: (Beta, 321–328)

#csl-bibliography()

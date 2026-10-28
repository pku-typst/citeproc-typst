#import "/lib.typ": csl-bibliography, init-csl-json

#let test-csl

#let refs = `[{"id": "foo", "type": "book", "title": "Foo"}]`.text
#let style = ```xml
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info>
    <title>Minimal</title>
    <id>minimal</id>
    <updated>2026-01-01T00:00:00+00:00</updated>
  </info>
  <citation>
    <layout prefix="[" suffix="]">
      <text variable="citation-number"/>
    </layout>
  </citation>
  <bibliography><layout><text variable="title"/></layout></bibliography>
</style>
```.text

#show: init-csl-json.with(refs, style)

#set page(numbering: "1")

// // Workaround, we always render it.body, so the layout converges
// #show link: it => {
//   if type(it.dest) != label { return it }
//   context {
//     let hits = query(it.dest)
//     if hits.len() == 0 {
//       it.body
//     } else {
//       link(hits.first().location(), it.body)
//     }
//   }
// }

// We fill the page, if @foo renders anything, it will pagebreak
#box(width: 100%, height: 100% - 12pt)@foo

#pagebreak()
#csl-bibliography()
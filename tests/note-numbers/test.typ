// Test: first-reference-note-number follows the actual footnote numbers
//
// Note numbers used to be counted as one per citation, which broke
// short-form citations ("supra note N") whenever
//   - a footnote written by the user contains no citation,
//   - a footnote written by the user contains several inline citations
//     (cite(form: "prose"), the usual way to cite inside a footnote),
//   - multicite puts several items into one footnote, or
//   - the footnote counter is reset (e.g. after title footnotes).
// Each "expect" comment below gives the correct output of that footnote.

#import "/lib.typ": csl-bibliography, init-csl-json, multicite

#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="note" version="1.0" default-locale="en-US">
  <info><title>Test</title><id>test</id><updated>2026-01-01T00:00:00+00:00</updated></info>
  <citation>
    <layout delimiter="; ">
      <choose>
        <if position="subsequent">
          <group delimiter=", ">
            <text variable="title" />
            <text variable="first-reference-note-number" prefix="supra note " />
          </group>
        </if>
        <else>
          <text variable="title" />
        </else>
      </choose>
    </layout>
  </citation>
  <bibliography><layout><text variable="title" /></layout></bibliography>
</style>
```.text

#let test-json = ```json
[
  {"id": "a", "type": "book", "title": "Alpha"},
  {"id": "b", "type": "book", "title": "Beta"},
  {"id": "c", "type": "book", "title": "Gamma"},
  {"id": "d", "type": "book", "title": "Delta"},
  {"id": "e", "type": "book", "title": "Epsilon"}
]
```.text

#show: init-csl-json.with(test-json, test-csl)

// Title footnotes, then the counter is reset
#set footnote(numbering: "*")
Title#footnote[Title note.]
#counter(footnote).update(0)
#set footnote(numbering: "1")

Footnote 1, no citation#footnote[Explanatory note.]

Footnote 2, ordinary citation @a

Footnote 3, two inline citations#footnote[Compare #cite(<b>, form: "prose") and #cite(<c>, form: "prose").]

Footnote 4, multicite #multicite("d", "e")

Footnote 5 @b[7] // expect: Beta, supra note 3

Footnote 6 @c[8] // expect: Gamma, supra note 3

Footnote 7 @e[9] // expect: Epsilon, supra note 4

Footnote 8 @a[10] // expect: Alpha, supra note 2

#csl-bibliography()

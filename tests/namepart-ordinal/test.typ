// Test fixture for CSL 1.0.2 name-part formatting and ordinal suffixes
//
// This test covers:
// 1. cs:name-part elements - per-part formatting (family uppercase+bold, given italic)
// 2. Ordinal suffixes - 1st, 2nd, 3rd, 11th, 21st
// 3. Long ordinals - first, second, third
// 4. Bibliography linking - DOI/URL auto-linking

#import "/lib.typ": csl-bibliography, init-csl-json

// =============================================================================
// Test CSL Style with name-part formatting and ordinals
// =============================================================================

#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info>
    <title>Test Style - Name-part and Ordinals</title>
    <id>test-namepart-ordinal</id>
  </info>
  <citation>
    <layout prefix="(" suffix=")" delimiter="; ">
      <group delimiter=", ">
        <names variable="author">
          <name form="short"/>
        </names>
        <date variable="issued">
          <date-part name="year"/>
        </date>
      </group>
    </layout>
  </citation>
  <bibliography>
    <layout suffix=".">
      <group delimiter=". ">
        <names variable="author">
          <name and="text" delimiter=", ">
            <name-part name="family" text-case="uppercase" font-weight="bold"/>
            <name-part name="given" font-style="italic"/>
          </name>
        </names>
        <date variable="issued" prefix="(" suffix=")">
          <date-part name="year"/>
        </date>
        <text variable="title"/>
        <group delimiter=" ">
          <number variable="edition" form="ordinal"/>
          <label variable="edition"/>
        </group>
        <group delimiter=" ">
          <number variable="volume" form="long-ordinal"/>
          <text value="volume"/>
        </group>
        <text variable="DOI" prefix="DOI: "/>
        <text variable="URL"/>
      </group>
    </layout>
  </bibliography>
</style>
```.text

// =============================================================================
// Test Bibliography Data (CSL-JSON)
// =============================================================================

#let test-json = ```json
[
  {
    "id": "smith2020",
    "type": "book",
    "title": "Name-part Formatting Test",
    "author": [
      {"family": "Smith", "given": "John"},
      {"family": "Jones", "given": "Mary Jane"}
    ],
    "edition": "1",
    "volume": "1",
    "issued": {"date-parts": [[2020]]},
    "DOI": "10.1234/example.2020"
  },
  {
    "id": "brown2021",
    "type": "book",
    "title": "Second Edition Test",
    "author": [
      {"family": "Brown", "given": "Alice"}
    ],
    "edition": "2",
    "volume": "2",
    "issued": {"date-parts": [[2021]]}
  },
  {
    "id": "davis2022",
    "type": "book",
    "title": "Third Edition Test",
    "author": [
      {"family": "Davis", "given": "Bob"}
    ],
    "edition": "3",
    "volume": "3",
    "issued": {"date-parts": [[2022]]}
  },
  {
    "id": "wilson2023",
    "type": "book",
    "title": "Eleventh Edition Test",
    "author": [
      {"family": "Wilson", "given": "Charlie"}
    ],
    "edition": "11",
    "volume": "10",
    "issued": {"date-parts": [[2023]]}
  },
  {
    "id": "taylor2024",
    "type": "book",
    "title": "Twenty-First Edition Test",
    "author": [
      {"family": "Taylor", "given": "Diana"}
    ],
    "edition": "21",
    "issued": {"date-parts": [[2024]]},
    "URL": "https://example.com/book"
  }
]
```.text

// =============================================================================
// Initialize and render
// =============================================================================

#show: init-csl-json.with(test-json, test-csl)

= Name-part Formatting and Ordinal Suffixes Test

== Test 1: Name-part Formatting

The `cs:name-part` element allows per-part formatting:
- Family names should be *UPPERCASE* and *bold*
- Given names should be _italic_

Citation: @smith2020

== Test 2: Ordinal Suffixes

Numbers rendered with `form="ordinal"` should use correct English suffixes:
- 1st, 2nd, 3rd (special cases)
- 11th, 12th, 13th (teen exception)
- 21st, 22nd, 23rd (twenty-x follows standard pattern)

Citations: @brown2021 @davis2022 @wilson2023 @taylor2024

== Test 3: Long Ordinals

Numbers rendered with `form="long-ordinal"` should use word forms:
- first, second, third, ... tenth
- Numbers > 10 fall back to ordinal form

== Test 4: Bibliography Linking

DOI and URL should be automatically hyperlinked:
- DOI links to https://doi.org/...
- URL links as-is

== Verification Checklist

=== Name-part Formatting
- [ ] "SMITH" is uppercase and bold
- [ ] "John" is italic
- [ ] "JONES" is uppercase and bold
- [ ] "Mary Jane" is italic

=== Ordinal Suffixes
- [ ] 1st edition (not 1th)
- [ ] 2nd edition (not 2th)
- [ ] 3rd edition (not 3th)
- [ ] 11th edition (not 11st)
- [ ] 21st edition (not 21th)

=== Long Ordinals
- [ ] "first volume" for volume 1
- [ ] "second volume" for volume 2
- [ ] "third volume" for volume 3
- [ ] "tenth volume" for volume 10

=== Bibliography Linking
- [ ] DOI is clickable
- [ ] URL is clickable

#pagebreak()

= Bibliography

#csl-bibliography()

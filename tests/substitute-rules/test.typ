// Test fixture for subsequent-author-substitute rules
//
// This test covers:
// - partial-first: Only substitute first author when it matches previous entry
//
// Expected behavior:
// - Entry 1: "Smith, John and Jones, Mary" (full names)
// - Entry 2: "———, and Jones, Mary" (same authors, but with partial-first only first is substituted)
// - Entry 3: "———, and Brown, Alice" (first author matches, substitute first only)

#import "/lib.typ": csl-bibliography, init-csl-json

// =============================================================================
// Test CSL Style with partial-first rule
// =============================================================================

#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info>
    <title>Test Style - Partial-First Substitute Rule</title>
    <id>test-partial-first</id>
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
  <bibliography
    subsequent-author-substitute="———"
    subsequent-author-substitute-rule="partial-first">
    <sort>
      <key variable="author"/>
      <key variable="issued"/>
    </sort>
    <layout suffix=".">
      <group delimiter=". ">
        <names variable="author">
          <name and="text" delimiter=", "/>
        </names>
        <date variable="issued" prefix="(" suffix=")">
          <date-part name="year"/>
        </date>
        <text variable="title"/>
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
    "type": "article-journal",
    "title": "First Article by Smith and Jones",
    "author": [
      {"family": "Smith", "given": "John"},
      {"family": "Jones", "given": "Mary"}
    ],
    "issued": {"date-parts": [[2020]]}
  },
  {
    "id": "smith2021",
    "type": "article-journal",
    "title": "Second Article by Same Authors",
    "author": [
      {"family": "Smith", "given": "John"},
      {"family": "Jones", "given": "Mary"}
    ],
    "issued": {"date-parts": [[2021]]}
  },
  {
    "id": "smith2022",
    "type": "article-journal",
    "title": "Article with Different Second Author",
    "author": [
      {"family": "Smith", "given": "John"},
      {"family": "Brown", "given": "Alice"}
    ],
    "issued": {"date-parts": [[2022]]}
  },
  {
    "id": "taylor2023",
    "type": "article-journal",
    "title": "Completely Different Authors",
    "author": [
      {"family": "Taylor", "given": "Bob"},
      {"family": "Wilson", "given": "Carol"}
    ],
    "issued": {"date-parts": [[2023]]}
  },
  {
    "id": "taylor2024",
    "type": "article-journal",
    "title": "Taylor Again with Wilson",
    "author": [
      {"family": "Taylor", "given": "Bob"},
      {"family": "Wilson", "given": "Carol"}
    ],
    "issued": {"date-parts": [[2024]]}
  }
]
```.text

// =============================================================================
// Initialize and render
// =============================================================================

#show: init-csl-json.with(test-json, test-csl)

= Subsequent-Author-Substitute: partial-first Rule

== Expected Behavior

With `subsequent-author-substitute-rule="partial-first"`:
- Only the *first author* is substituted if it matches the previous entry
- Other authors are rendered normally

== Test Cases

Citations for all entries: @smith2020 @smith2021 @smith2022 @taylor2023 @taylor2024

== Expected Bibliography Output

1. *Smith, John and Jones, Mary.* (2020). First Article...
  - Full names (first entry)

2. *———, and Jones, Mary.* (2021). Second Article...
  - All authors match → all substituted (complete match triggers full substitute)

3. *———, and Brown, Alice.* (2022). Article with Different...
  - First author matches → only first substituted

4. *Taylor, Bob and Wilson, Carol.* (2023). Completely Different...
  - No match → full names

5. *———, and Wilson, Carol.* (2024). Taylor Again...
  - All authors match → all substituted

== Verification Checklist

- [ ] Entry 1: Full author names
- [ ] Entry 2: All names substituted (complete match)
- [ ] Entry 3: Only first author substituted, "Brown, Alice" shown
- [ ] Entry 4: Full author names (new author sequence)
- [ ] Entry 5: All names substituted (complete match)

#pagebreak()

= Bibliography

#csl-bibliography()

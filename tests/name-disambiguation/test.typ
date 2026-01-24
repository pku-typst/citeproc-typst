// Test name disambiguation according to CSL specification
//
// CSL Methods (applied in order):
// 1. disambiguate-add-givenname: Add initials or full given names
// 2. disambiguate-add-names: Add more authors from et-al list
// 3. disambiguate condition: Custom disambiguation via <choose>
// 4. disambiguate-add-year-suffix: Add a, b, c to years
//
// Key principle: Each method only applies to entries still ambiguous
// after previous methods. Year-suffix is the last resort.
//
// Implementation status: FULLY IMPLEMENTED
// - The algorithm correctly applies methods in order
// - Year-suffix only assigned to entries that cannot be disambiguated
//   by given name expansion or adding more author names

#import "/lib.typ": csl-bibliography, init-csl

// Style with all disambiguation methods enabled
#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info>
    <title>Test Name Disambiguation</title>
    <id>test-name-disambiguation</id>
  </info>
  <citation
    et-al-min="3"
    et-al-use-first="1"
    disambiguate-add-givenname="true"
    disambiguate-add-names="true"
    givenname-disambiguation-rule="all-names"
    disambiguate-add-year-suffix="true">
    <layout prefix="(" suffix=")" delimiter="; ">
      <group delimiter=", ">
        <names variable="author">
          <name form="short"/>
        </names>
        <group>
          <date variable="issued">
            <date-part name="year"/>
          </date>
          <text variable="year-suffix"/>
        </group>
      </group>
    </layout>
  </citation>
  <bibliography et-al-min="3" et-al-use-first="1">
    <sort>
      <key variable="citation-number"/>
    </sort>
    <layout suffix=".">
      <group delimiter=". ">
        <names variable="author">
          <name initialize-with=". " name-as-sort-order="all"/>
        </names>
        <group prefix="(" suffix=")">
          <date variable="issued">
            <date-part name="year"/>
          </date>
          <text variable="year-suffix"/>
        </group>
        <text variable="title"/>
      </group>
    </layout>
  </bibliography>
</style>
```.text

// Test entries:
// - J. Smith and A. Smith (same surname, different given names)
// - J. Smith with two different papers in 2020 (need year-suffix)
// - Multiple author teams with same first author
#let test-bib = ```bib
@article{jsmith2020a,
  author = {Smith, John},
  title = {First Paper by John Smith},
  year = {2020},
}

@article{asmith2020,
  author = {Smith, Amy},
  title = {Paper by Amy Smith},
  year = {2020},
}

@article{jsmith2020b,
  author = {Smith, John},
  title = {Second Paper by John Smith},
  year = {2020},
}

@article{team1-2021,
  author = {Johnson, Mary and Williams, Tom and Davis, Chris and Miller, Jane},
  title = {Team 1 Paper},
  year = {2021},
}

@article{team2-2021,
  author = {Johnson, Mary and Williams, Tom and Anderson, Pat and Taylor, Sam},
  title = {Team 2 Paper},
  year = {2021},
}
```.text

#show: init-csl.with(test-bib, test-csl)

= Name Disambiguation Test

== Test Case 1: Same Surname, Different Given Names

When two authors share the same surname but have different given names, disambiguation should add initials or full given names.

- John Smith: @jsmith2020a
- Amy Smith: @asmith2020

Expected behavior:
- (J. Smith, 2020) vs (A. Smith, 2020) - initials should disambiguate

== Test Case 2: Same Author, Same Year (Year Suffix)

When the same author publishes multiple papers in the same year:

- First paper: @jsmith2020a
- Second paper: @jsmith2020b

Expected behavior:
- Should get year suffixes (2020a, 2020b)

== Test Case 3: Teams with Same First Author

When multiple author teams share the same first author (with et-al), disambiguation should add more names.

- Team 1: @team1-2021
- Team 2: @team2-2021

Expected behavior:
- "Johnson et al., 2021" is ambiguous
- Should expand to show more authors: "Johnson, Williams, Davis, et al." vs "Johnson, Williams, Anderson, et al."

== Bibliography

#csl-bibliography()

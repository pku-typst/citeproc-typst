// Test fixture for CSL 1.0.2 name-related features
//
// This test covers:
// 1. et-al-use-last: Show ellipsis and last author (e.g., "Doe, ... Smith")
// 2. et-al-subsequent-min/use-first: Different et-al for subsequent cites
// 3. subsequent-author-substitute: Replace repeated authors with substitute string
// 4. names-min/use-first/use-last: Override et-al in sort keys

#import "../lib.typ": csl-bibliography, init-csl

// =============================================================================
// Test CSL Style with comprehensive name features
// =============================================================================

#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info>
    <title>Test Style - Name Features</title>
    <id>test-name-features</id>
  </info>
  <citation
    et-al-min="4"
    et-al-use-first="1"
    et-al-subsequent-min="3"
    et-al-subsequent-use-first="1">
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
    et-al-min="6"
    et-al-use-first="3"
    et-al-use-last="true"
    subsequent-author-substitute="———"
    subsequent-author-substitute-rule="complete-all">
    <sort>
      <key macro="author" names-min="99" names-use-first="99"/>
      <key variable="issued"/>
    </sort>
    <layout suffix=".">
      <group delimiter=". ">
        <text macro="author"/>
        <date variable="issued" prefix="(" suffix=")">
          <date-part name="year"/>
        </date>
        <text variable="title"/>
      </group>
    </layout>
  </bibliography>
  <macro name="author">
    <names variable="author">
      <name and="text" delimiter=", " delimiter-precedes-last="always"/>
    </names>
  </macro>
</style>
```.text

// =============================================================================
// Test Bibliography Data
// =============================================================================

#let test-bib = ```bib
% Single author - no et-al
@article{single2020,
  author = {Aaa, A.},
  title = {Single Author Article},
  journal = {Test Journal},
  year = {2020},
}

% Two authors - no et-al
@article{two2020,
  author = {Bbb, B. and Ccc, C.},
  title = {Two Author Article},
  journal = {Test Journal},
  year = {2020},
}

% Three authors - tests et-al behavior
@article{three2020,
  author = {Ddd, D. and Eee, E. and Fff, F.},
  title = {Three Author Article},
  journal = {Test Journal},
  year = {2020},
}

% Four authors - et-al in all cites
@article{four2020,
  author = {Ggg, G. and Hhh, H. and Iii, I. and Jjj, J.},
  title = {Four Author Article},
  journal = {Test Journal},
  year = {2020},
}

% Five authors - et-al in all cites, no et-al-use-last in bibliography
@article{five2020,
  author = {Kkk, K. and Lll, L. and Mmm, M. and Nnn, N. and Ooo, O.},
  title = {Five Author Article},
  journal = {Test Journal},
  year = {2020},
}

% Seven authors - triggers et-al-use-last in bibliography (6+ authors)
@article{seven2020,
  author = {Alpha, A. and Beta, B. and Gamma, G. and Delta, D. and Epsilon, E. and Zeta, Z. and Omega, O.},
  title = {Seven Author Article with Et-Al-Use-Last},
  journal = {Test Journal},
  year = {2020},
}

% Eight authors - also triggers et-al-use-last
@article{eight2020,
  author = {Alpha, A. and Beta, B. and Gamma, G. and Delta, D. and Epsilon, E. and Zeta, Z. and Eta, H. and Omega, O.},
  title = {Eight Author Article with Et-Al-Use-Last},
  journal = {Test Journal},
  year = {2020},
}

% Same authors as seven2020 - tests subsequent-author-substitute
@article{seven2020b,
  author = {Alpha, A. and Beta, B. and Gamma, G. and Delta, D. and Epsilon, E. and Zeta, Z. and Omega, O.},
  title = {Another Seven Author Article - Should Use Substitute},
  journal = {Test Journal},
  year = {2021},
}

% Editor only (tests substitute in names)
@book{editor2020,
  editor = {Editor, Ed},
  title = {Edited Book},
  publisher = {Test Publisher},
  year = {2020},
}

% Exactly at et-al-min threshold (6 authors)
@article{six2020,
  author = {One, A. and Two, B. and Three, C. and Four, D. and Five, E. and Six, F.},
  title = {Exactly Six Authors - At Threshold},
  journal = {Test Journal},
  year = {2020},
}
```.text

// =============================================================================
// Initialize and render
// =============================================================================

#show: init-csl.with(test-bib, test-csl)

= CSL 1.0.2 Name Features Test

== Test 1: Et-al Behavior in First vs Subsequent Cites

*First citation (et-al-min=4, et-al-use-first=1):*

- Single author: @single2020 → should show "Aaa"
- Two authors: @two2020 → should show "Bbb and Ccc"
- Three authors: @three2020 → should show "Ddd, Eee, and Fff" (below threshold)
- Four authors: @four2020 → should show "Ggg et al." (at threshold)

*Subsequent citations (et-al-subsequent-min=3, et-al-subsequent-use-first=1):*

- Three authors again: @three2020 → should show "Ddd et al." (subsequent)
- Four authors again: @four2020 → should show "Ggg et al." (subsequent)

== Test 2: Et-al-use-last in Bibliography

The bibliography should show:
- For 7+ authors: "Alpha, Beta, Gamma, … Omega" (with ellipsis and last author)
- For exactly 6 authors: "One, Two, Three, … Six" (at threshold, needs 2+ more than shown)

Citations for bibliography entries:
@seven2020 @eight2020 @six2020

== Test 3: Subsequent-Author-Substitute

These entries have identical authors and should show "———" for the second entry:
@seven2020 @seven2020b

== Test 4: Names Substitute (Editor Fallback)

Entry with editor only: @editor2020

== Test 5: Five Authors (Below et-al-use-last Threshold)

@five2020 - In bibliography, should show all 5 authors (below bib et-al-min=6)

== Verification Checklist

=== Citations
- [ ] Single author shows full name
- [ ] Two authors connected with "and"
- [ ] Three authors: first cite shows all, subsequent shows et-al
- [ ] Four+ authors always show et-al

=== Bibliography (check PDF output)
- [ ] 7+ authors show: first 3 + "…" + last author
- [ ] Repeated authors replaced with "———"
- [ ] Editor shown when no author

=== Sort Keys
- [ ] Entries sorted by full author list (names-min=99 overrides et-al)
- [ ] Then by year

#pagebreak()

= Bibliography

#csl-bibliography()

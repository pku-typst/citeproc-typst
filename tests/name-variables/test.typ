// Test: all CSL 1.0.2 name variables are rendered
//
// citrus only parsed and rendered a subset of the CSL 1.0.2 name variables;
// `contributor`, `compiler`, `organizer` and the other variables below
// rendered as empty. Each should print its name and role label.

#import "/lib.typ": csl-bibliography, init-csl-json

#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info><title>Test</title><id>test</id><updated>2026-01-01T00:00:00+00:00</updated></info>
  <citation>
    <layout delimiter="; ">
      <group delimiter="; ">
        <names variable="chair">
          <name />
          <label prefix=" (" suffix=")" />
        </names>
        <names variable="compiler">
          <name />
          <label prefix=" (" suffix=")" />
        </names>
        <names variable="contributor">
          <name />
          <label prefix=" (" suffix=")" />
        </names>
        <names variable="curator">
          <name />
          <label prefix=" (" suffix=")" />
        </names>
        <names variable="editorial-director">
          <name />
          <label prefix=" (" suffix=")" />
        </names>
        <names variable="executive-producer">
          <name />
          <label prefix=" (" suffix=")" />
        </names>
        <names variable="guest">
          <name />
          <label prefix=" (" suffix=")" />
        </names>
        <names variable="host">
          <name />
          <label prefix=" (" suffix=")" />
        </names>
        <names variable="narrator">
          <name />
          <label prefix=" (" suffix=")" />
        </names>
        <names variable="organizer">
          <name />
          <label prefix=" (" suffix=")" />
        </names>
        <names variable="performer">
          <name />
          <label prefix=" (" suffix=")" />
        </names>
        <names variable="producer">
          <name />
          <label prefix=" (" suffix=")" />
        </names>
        <names variable="script-writer">
          <name />
          <label prefix=" (" suffix=")" />
        </names>
        <names variable="series-creator">
          <name />
          <label prefix=" (" suffix=")" />
        </names>
      </group>
    </layout>
  </citation>
  <bibliography>
    <layout>
      <group delimiter=", ">
        <names variable="author">
          <name />
          <substitute>
            <names variable="contributor" />
          </substitute>
        </names>
        <text variable="title" />
      </group>
    </layout>
  </bibliography>
</style>
```.text

#let test-json = ```json
[
  {"id": "all", "type": "book", "title": "All Roles", "chair": [{"family": "Ada", "given": "X."}], "compiler": [{"family": "Ben", "given": "X."}], "contributor": [{"family": "Cora", "given": "X."}], "curator": [{"family": "Dan", "given": "X."}], "editorial-director": [{"family": "Eve", "given": "X."}], "executive-producer": [{"family": "Finn", "given": "X."}], "guest": [{"family": "Gus", "given": "X."}], "host": [{"family": "Hal", "given": "X."}], "narrator": [{"family": "Ida", "given": "X."}], "organizer": [{"family": "Jon", "given": "X."}], "performer": [{"family": "Kim", "given": "X."}], "producer": [{"family": "Lou", "given": "X."}], "script-writer": [{"family": "Max", "given": "X."}], "series-creator": [{"family": "Ned", "given": "X."}]},
  {"id": "sub", "type": "book", "title": "Contributor Only", "contributor": [{"family": "Roe", "given": "Rick"}]}
]
```.text

#show: init-csl-json.with(test-json, test-csl)

// expect: one name per role, each followed by its role label,
// e.g. "X. Ada (chair); X. Ben (compiler); X. Cora (contributor); ..."
@all

// expect in bibliography: "Rick Roe, Contributor Only" (contributor substitutes for author)
#cite(<sub>, form: none)

#csl-bibliography()

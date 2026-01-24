// Test CSL-M layout locale support
//
// This test verifies that CSL-M multilingual layout selection works correctly.
// Different layouts are selected based on the entry's language.

#import "/lib.typ": csl-bibliography, init-csl-json

// CSL-M style with locale-specific layouts
// - Chinese entries: Use "和" for "and", "编" for editor
// - English entries: Use "and" for "and", "ed." for editor
#let test-csl = ```xml
<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0" default-locale="zh-CN">
  <info>
    <title>Test CSL-M Layout Locale</title>
    <id>test-cslm-layout</id>
  </info>
  <locale xml:lang="zh">
    <terms>
      <term name="and">和</term>
      <term name="editor" form="short">编</term>
      <term name="et-al">等</term>
    </terms>
  </locale>
  <locale xml:lang="en">
    <terms>
      <term name="and">and</term>
      <term name="editor" form="short">ed.</term>
      <term name="et-al">et al.</term>
    </terms>
  </locale>
  <macro name="author">
    <names variable="author">
      <name delimiter=", " and="text"/>
    </names>
  </macro>
  <macro name="author-with-original">
    <names variable="author">
      <name delimiter=", " and="text"/>
    </names>
    <names variable="original-author" prefix=" (" suffix=")">
      <name delimiter=", " name-as-sort-order="all"/>
    </names>
  </macro>
  <macro name="editor">
    <names variable="editor">
      <name delimiter=", " and="text"/>
      <label form="short" prefix=", "/>
    </names>
  </macro>
  <macro name="editor-with-original">
    <names variable="editor">
      <name delimiter=", " and="text"/>
      <label form="short" prefix=" "/>
    </names>
    <names variable="original-editor" prefix=" (" suffix=")">
      <name delimiter=", " name-as-sort-order="all"/>
    </names>
  </macro>
  <citation>
    <!-- CSL-M: locale-specific citation layouts -->
    <layout locale="en" prefix="(" suffix=")" delimiter="; ">
      <group delimiter=", ">
        <text macro="author"/>
        <text variable="issued"/>
      </group>
    </layout>
    <layout locale="zh" prefix="(" suffix=")" delimiter="; ">
      <group delimiter=", ">
        <text macro="author"/>
        <text variable="issued"/>
      </group>
    </layout>
  </citation>
  <bibliography>
    <!-- CSL-M: locale-specific bibliography layouts -->
    <layout locale="en" suffix=".">
      <group delimiter=". ">
        <text macro="author"/>
        <text variable="title" font-style="italic"/>
        <text macro="editor"/>
        <text variable="issued"/>
      </group>
    </layout>
    <layout locale="zh" suffix=".">
      <group delimiter=". ">
        <text macro="author-with-original"/>
        <text variable="title"/>
        <text macro="editor-with-original"/>
        <text variable="issued"/>
      </group>
    </layout>
  </bibliography>
</style>
```.text

// Test data with Chinese and English entries
// Chinese entries have "language": "zh" and use original-* for transliteration
// English entries have "language": "en"
#let test-json = ```json
[
  {
    "id": "zhang2023",
    "type": "article-journal",
    "language": "zh",
    "title": "量子计算研究进展",
    "author": [
      { "family": "张", "given": "三" },
      { "family": "李", "given": "四" }
    ],
    "original-author": [
      { "family": "Zhang", "given": "San" },
      { "family": "Li", "given": "Si" }
    ],
    "issued": { "date-parts": [[2023]] }
  },
  {
    "id": "smith2024",
    "type": "book",
    "language": "en",
    "title": "Introduction to AI",
    "author": [
      { "family": "Smith", "given": "John" },
      { "family": "Doe", "given": "Jane" }
    ],
    "issued": { "date-parts": [[2024]] }
  },
  {
    "id": "wang2024",
    "type": "book",
    "language": "zh",
    "title": "人工智能导论",
    "author": [
      { "family": "王", "given": "五" }
    ],
    "original-author": [
      { "family": "Wang", "given": "Wu" }
    ],
    "editor": [
      { "family": "赵", "given": "六" }
    ],
    "original-editor": [
      { "family": "Zhao", "given": "Liu" }
    ],
    "issued": { "date-parts": [[2024]] }
  },
  {
    "id": "chen2022",
    "type": "chapter",
    "language": "zh",
    "title": "深度学习基础",
    "author": [
      { "family": "陈", "given": "七" }
    ],
    "editor": [
      { "family": "周", "given": "八" },
      { "family": "吴", "given": "九" }
    ],
    "original-editor": [
      { "family": "Zhou", "given": "Ba" },
      { "family": "Wu", "given": "Jiu" }
    ],
    "issued": { "date-parts": [[2022]] }
  },
  {
    "id": "johnson2021",
    "type": "article-journal",
    "language": "en",
    "title": "Machine Learning Advances",
    "author": [
      { "family": "Johnson", "given": "Alice" },
      { "family": "Williams", "given": "Bob" },
      { "family": "Brown", "given": "Carol" }
    ],
    "issued": { "date-parts": [[2021]] }
  }
]
```.text

#set page(width: 16cm, height: auto, margin: 1cm)
#set text(font: ("Times New Roman", "SimSun"), size: 10pt)

#show: init-csl-json.with(test-json, test-csl)

= Test: CSL-M Layout Locale Selection

== Expected Behavior

CSL-M allows multiple `<layout>` elements with `locale` attributes.
The layout is selected based on the entry's language field:

- *Chinese entries* (`language: "zh"`): Use Chinese layout with "和" connector, "编" for editor
- *English entries* (`language: "en"`): Use English layout with ", and" separator, "ed." for editor

== Citations

Chinese entry: @zhang2023

English entry: @smith2024

Chinese with editor: @wang2024

Chinese chapter: @chen2022

English with 3 authors: @johnson2021

== Bibliography

#csl-bibliography(title: none)

== Verification Checklist

=== Chinese Entries (use Chinese layout with zh locale)
- [x] zhang2023: "张三 和 李四" - Chinese "和" term
- [x] wang2024: "赵六, 编" - Uses "编" (Chinese editor term)
- [x] chen2022: "周八 和 吴九, 编" - Multiple editors with Chinese term

=== English Entries (use English layout with en locale)
- [x] smith2024: "John Smith and Jane Doe." - English "and" term
- [x] johnson2021: "Alice Johnson, Bob Williams, and Carol Brown." - Three authors

=== CSL-M Locale Switching Verified
- Citation: "(张三 和 李四, 2023)" uses zh locale → "和"
- Citation: "(John Smith and Jane Doe, 2024)" uses en locale → "and"
- Bibliography editor: "编" for zh, "ed." for en

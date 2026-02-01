# Known Issues and Differences

This document tracks known issues, limitations, and differences from citeproc-js behavior.

---

## Number/Ordinal Category (7 remaining issues)

### 1. Bibliography Mode Empty Output

**Test:** `number_LimitOrdinalsToDayOne`

**Issue:** Bibliography mode tests produce no output. The test framework may not properly trigger bibliography rendering.

**Status:** Test infrastructure issue

---

### 2. Ordinal Gender Matching

**Tests:** `number_NewOrdinalsEdition`, `number_NewOrdinalsWithGenderChange`, `number_SeparateOrdinalNamespaces`

**Issue:** French/Spanish ordinals need to match the gender of the noun they modify:

- `edition` (feminine) → `1ʳᵉ` (première)
- `issue` (masculine) → `1ᵉʳ` (premier)

**Expected:** `1<sup>r</sup><sup>e</sup> éd.`
**Actual:** `1ᵉ éd.` or `1ᵉʳ éd.` (wrong gender)

**Root Cause:** Ordinal suffix selection doesn't use `term-genders` and `ordinal-gender-forms` from locale.

**Status:** Locale data now includes gender info; implementation needed in `interpreter/number.typ`

---

### 3. Complex Number Value Parsing

**Test:** `number_OrdinalSpacing`

**Issue:** Edition value `"7, p. 3-8"` contains multiple parts. CSL requires:

1. Parse `7` as ordinal → `7th`
2. Preserve `, ` delimiter
3. Parse `p. 3-8` → `pp. 3–8` (plural label, en-dash)

**Expected:** `7th, pp. 3–8`
**Actual:** `7th` (rest missing)

**Status:** Not implemented - need complex `<number>` value parsing

---

### 4. Escaped Hyphen Handling

**Test:** `number_PlainHyphenOrEnDashAlwaysPlural`

**Issue:** citeproc-js uses `\-` in test data to prevent hyphen→en-dash conversion. Our implementation doesn't handle this escape sequence.

**Expected (for `3-B`):** `page 3-B` (singular, plain hyphen)
**Actual:** May convert hyphen incorrectly

**Status:** citeproc-js specific feature, may need exclusion

---

### 5. Trailing Comma in Names

**Test:** `number_PreserveDelimiter`

**Issue:** Output has extra comma: `Brown, , editors` instead of `Brown, editors`

**Root Cause:** Names/label joining logic adds extra delimiter.

**Status:** Bug in names rendering

---

## Date Formatting

### AD/BC Year Suffix

**Test:** `collapse_AuthorCollapseNoDateSorted`

**Expected:** `(Smith 325 AD, 2000)`
**Actual:** `(Smith 0325, 2000, )`

**Issues:**

1. Years before 1000 AD are not formatted with "AD" suffix
2. Trailing delimiter appears when it shouldn't

**CSL Spec Reference:** Section "AD and BC"

> The "ad" term (Anno Domini) is automatically appended to positive years of less than four digits (e.g. "79" becomes "79AD"). The "bc" term (Before Christ) is automatically appended to negative years (e.g. "-2500" becomes "2500BC").

**Status:** Not implemented

**Priority:** Low (rare use case)

---

## Spec Interpretation Differences

### after-collapse-delimiter Scope

**Test:** `collapse_ChicagoAfterCollapse` (excluded)

**Difference:** citeproc-js applies `after-collapse-delimiter` to all author groups when collapse is enabled. Our implementation only uses it after groups that actually collapsed (multiple items for same author).

**CSL Spec Quote:**

> after-collapse-delimiter: Specifies the cite delimiter to be used _after_ a collapsed cite group.

**Our Interpretation:** Literal - only use after a group that actually collapsed.

**citeproc-js Behavior:** Uses after-collapse-delimiter between all author groups when collapse mode is active.

**Decision:** Follow spec literally. Excluded from test comparison.

---

## citeproc-js Specific Features

### Dynamic Citation Updates

**Test:** `collapse_CitationNumberRangesInsert` (excluded)

citeproc-js supports dynamic citation update formats with `..[n]` and `>>[n]` prefixes for testing citation insertion/reordering. This is not applicable to Typst's static compilation model.

**Status:** Excluded from comparison (not a bug)

---

## Condition Category (4 remaining issues)

### 1. Locator Condition Order

**Test:** `condition_LocatorIsFalse`

**Issue:** Locator true/false conditions return in wrong order for multi-citation.

**Status:** Logic bug in locator condition evaluation

---

### 2. Bibliography Mode Tests

**Tests:** `condition_RefTypeBranching`, `condition_SingletonIfMatchNone`

**Issue:** Bibliography mode tests produce no output or wrong format.

**Status:** Test infrastructure / bibliography rendering issue

---

## Group Category (COMPLETE)

All tests passing (2 excluded for valid reasons).

**Fixed issues:**

- Month format now defaults to "long" (June instead of 6)
- URL/DOI/ISBN/ISSN field mapping fixed for CSL-JSON
- Added `and-symbol` (&) term to locales
- Fixed BibliographyExtractor to preserve italic formatting

### citeproc-js Macro-as-Group Hack

**Source:** `references/citeproc-js/src/node_text.js` lines 6-20

citeproc-js **explicitly wraps macro calls in group nodes**:

```javascript
if (this.postponed_macro) {
  var group_start = CSL.Util.cloneToken(this);
  group_start.name = "group";
  // ... build group START
  CSL.expandMacro.call(state, this, target);
  // ... build group END
}
```

CSL spec says group has suppress logic, but doesn't say macro should behave like group. citeproc-js implements this by wrapping macros in groups.

**Our decision:** We implement the same behavior (macro acts like implicit group) because:

1. Test `group_SuppressTermInMacro` expects this behavior
2. It's a reasonable interpretation for style authors
3. Without it, terms in macros would leak when variables are empty

---

### citeproc-js year-suffix Hack

**Source:** `references/citeproc-js/src/attributes.js` lines 296-301

citeproc-js has a special case: `year-suffix` is hardcoded to "always produce output" even when empty. This prevents group suppression for patterns like:

```xml
<group prefix=" (" suffix=").">
  <text term="no date" form="short"/>
  <text variable="year-suffix" prefix="-"/>
</group>
```

Without the hack, this group would be suppressed when `year-suffix` is empty (per CSL spec). With the hack, it outputs `(n.d.)`.

**Our decision:** We follow the CSL spec strictly. We do not implement this hack because:

1. It's not in the CSL specification
2. Style authors can work around it by restructuring their CSL
3. It introduces special-case complexity

**Status:** 4/5 pass (2 excluded, 1 mismatch)

---

## Label Category (8 remaining issues)

Issues include:

- Page number plural detection with collapsed ranges
- Missing name labels after names
- `&` symbol not using localized term (`and` form="symbol")
- Extra delimiters in name/label output

---

## Test Infrastructure Notes

### Bibliography HTML Format

Some tests expect `<div class="csl-bib-body">` wrapper which our citation output doesn't include. These tests pass content comparison but fail format comparison.

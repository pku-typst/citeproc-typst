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

## Group Category (2 remaining issues)

### CSL Processing Gaps

**Tests:** `group_ComplexNesting`, `group_SuppressWithEmptyNestedDateNode`

**Fixed issues:**

- Month format now defaults to "long" (June instead of 6)
- URL/DOI/ISBN/ISSN field mapping fixed for CSL-JSON

**Remaining issues in `group_ComplexNesting`:**

- Missing `(n.d.)` - the issued macro's else branch group is suppressed because year-suffix is empty

**Remaining issues in `group_SuppressWithEmptyNestedDateNode`:**

- Name delimiter shows `and` instead of `&` (`&#38;`) - locale term issue
- Missing italic formatting on journal title - HTML extraction issue

**Status:** CSL processing gaps (group suppress edge cases)

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

#!/usr/bin/env python3
"""
CSL Test Suite Runner for citrus

Uses Typst HTML export to compare citation/bibliography output against
the official CSL test-suite fixtures.

Usage:
    python scripts/run-test-suite.py [--limit N] [--category CATEGORY] [--verbose] [--compare]
"""

import os
import sys
import re
import json
import subprocess
import argparse
from pathlib import Path
from dataclasses import dataclass
from typing import Optional, List, Dict, Any
from collections import defaultdict
from html.parser import HTMLParser

# =============================================================================
# HTML Text Extractor
# =============================================================================

class CitationExtractor(HTMLParser):
    """Extract citation text from HTML (content before bibliography refs)."""

    def __init__(self):
        super().__init__()
        self.in_body = False
        self.in_p = False
        self.current_p_text = []
        self.citation_texts = []
        self.current_span_id = None
        self.skip_current_p = False

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        if tag == 'body':
            self.in_body = True
        elif tag == 'p' and self.in_body:
            self.in_p = True
            self.current_p_text = []
            self.skip_current_p = False
        elif tag == 'span':
            span_id = attrs_dict.get('id', '')
            if span_id.startswith('citeproc-ref-'):
                self.skip_current_p = True

    def handle_endtag(self, tag):
        if tag == 'p' and self.in_p:
            self.in_p = False
            if not self.skip_current_p:
                text = ''.join(self.current_p_text).strip()
                if text:
                    self.citation_texts.append(text)

    def handle_data(self, data):
        if self.in_p and not self.skip_current_p:
            self.current_p_text.append(data)

    def get_citations(self) -> str:
        return '\n'.join(self.citation_texts)


class BibliographyExtractor(HTMLParser):
    """Extract bibliography entries from HTML (spans with citeproc-ref- ids)."""

    def __init__(self):
        super().__init__()
        self.entries = []
        self.in_bib_span = False
        self.current_entry_text = []
        self.tag_stack = []

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        if tag == 'span':
            span_id = attrs_dict.get('id', '')
            if span_id.startswith('citeproc-ref-'):
                self.in_bib_span = True
                self.current_entry_text = []
                self.tag_stack = ['span']
                return
        if self.in_bib_span:
            self.tag_stack.append(tag)

    def handle_endtag(self, tag):
        if self.in_bib_span:
            if self.tag_stack and self.tag_stack[-1] == tag:
                self.tag_stack.pop()
            if not self.tag_stack:
                # End of bibliography span
                self.in_bib_span = False
                text = ''.join(self.current_entry_text).strip()
                if text:
                    self.entries.append(text)

    def handle_data(self, data):
        if self.in_bib_span:
            self.current_entry_text.append(data)

    def get_entries(self) -> str:
        return '\n'.join(self.entries)


def extract_citation_from_html(html: str) -> str:
    """Extract citation text from HTML."""
    parser = CitationExtractor()
    parser.feed(html)
    return parser.get_citations()


def extract_bibliography_from_html(html: str) -> str:
    """Extract bibliography entries from HTML."""
    parser = BibliographyExtractor()
    parser.feed(html)
    return parser.get_entries()


def extract_output_from_html(html: str, mode: str) -> str:
    """Extract appropriate content from HTML based on test mode."""
    if mode.startswith('bibliography'):
        return extract_bibliography_from_html(html)
    else:
        return extract_citation_from_html(html)


# =============================================================================
# XML Patches
# =============================================================================

def load_csl_patches() -> Dict[str, Dict[str, str]]:
    """Load CSL XML patches from the patches directory."""
    patches_file = Path(__file__).parent / 'patches' / 'csl-xml-fixes.json'
    if patches_file.exists():
        with open(patches_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return {p['fixture']: p for p in data.get('patches', [])}
    return {}

CSL_PATCHES = load_csl_patches()

def apply_csl_patch(fixture_name: str, csl_content: str) -> str:
    """Apply XML patch for a fixture if one exists."""
    patch = CSL_PATCHES.get(fixture_name)
    if patch:
        csl_content = csl_content.replace(patch['find'], patch['replace'])
    return csl_content


# =============================================================================
# Fixture Parsing (supports both test-suite and citeproc-js formats)
# =============================================================================

@dataclass
class TestFixture:
    """Represents a CSL test fixture."""
    name: str
    mode: str
    result: str
    csl: str
    input_data: List[Dict[str, Any]]
    citation_items: Optional[List[Any]] = None
    citations: Optional[List[Any]] = None
    abbreviations: Optional[Dict[str, Any]] = None


def parse_fixture(filepath: Path) -> Optional[TestFixture]:
    """Parse a CSL test fixture file (supports multiple formats)."""
    content = filepath.read_text(encoding='utf-8')

    def extract_section(name: str) -> Optional[str]:
        # Support both formats: >>==== NAME ====>> and >>===== NAME =====>>
        pattern = rf'>>==+\s*{name}\s*==+>>(.+?)<<==+\s*{name}\s*==+<<'
        match = re.search(pattern, content, re.DOTALL)
        return match.group(1).strip() if match else None

    mode = extract_section('MODE')
    result = extract_section('RESULT')
    csl = extract_section('CSL')
    input_raw = extract_section('INPUT')

    if not all([mode, result, csl, input_raw]):
        return None

    try:
        input_data = json.loads(input_raw)
    except json.JSONDecodeError:
        return None

    # Optional sections
    citation_items_raw = extract_section('CITATION-ITEMS')
    citations_raw = extract_section('CITATIONS')
    abbrevs_raw = extract_section('ABBREVIATIONS')

    try:
        citation_items = json.loads(citation_items_raw) if citation_items_raw else None
        citations = json.loads(citations_raw) if citations_raw else None
        abbreviations = json.loads(abbrevs_raw) if abbrevs_raw else None
    except json.JSONDecodeError:
        citation_items = None
        citations = None
        abbreviations = None

    return TestFixture(
        name=filepath.stem,
        mode=mode,
        result=result,
        csl=csl,
        input_data=input_data,
        citation_items=citation_items,
        citations=citations,
        abbreviations=abbreviations,
    )


# =============================================================================
# CSL-JSON Handling
# =============================================================================

def normalize_csl_json(items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Normalize CSL-JSON items."""
    normalized = []
    for i, item in enumerate(items):
        item_copy = item.copy()
        if 'id' not in item_copy:
            item_copy['id'] = f'ITEM-{i+1}'
        normalized.append(item_copy)
    return normalized


# =============================================================================
# Typst Test Generation
# =============================================================================

def generate_typst_test(fixture: TestFixture, json_path: str, csl_path: str,
                        csl_content: str = None, abbrevs_path: str = None) -> str:
    """Generate a Typst test file for a fixture.

    Uses a simplified rendering approach for HTML export compatibility:
    - Directly renders citations without footnote/link wrappers
    - Uses prose form to avoid superscript issues
    - Uses multicite for clusters with multiple citations
    """

    check_csl = csl_content if csl_content else fixture.csl
    is_bib_mode = fixture.mode.startswith('bibliography')

    # Build abbreviations parameter
    abbrevs_param = ''
    if abbrevs_path:
        abbrevs_param = f',\n  abbreviations: json("/{abbrevs_path}")'

    if is_bib_mode:
        # Bibliography mode - need hidden citations to populate bibliography
        # Use box(width: 0pt) to hide citations (hide is ignored in HTML export)
        hidden_cites = []
        for item in fixture.input_data:
            key = item.get('id', 'ITEM-1')
            hidden_cites.append(f'#box(width: 0pt, height: 0pt, clip: true)[#cite(<{key}>)]')
        hidden_cites_str = '\n'.join(hidden_cites)
        body = f'''// Bibliography mode - hidden citations to populate bibliography
{hidden_cites_str}

#csl-bibliography(title: none)'''
    else:
        # Process citation clusters
        cite_calls = []

        if fixture.citation_items:
            for cluster in fixture.citation_items:
                if len(cluster) == 1:
                    # Single citation - use #cite
                    cite = cluster[0]
                    if isinstance(cite, dict) and 'id' in cite:
                        key = cite['id']
                        cite_calls.append(f'#cite(<{key}>, form: "prose")')
                elif len(cluster) > 1:
                    # Multiple citations - use #multicite
                    keys = []
                    for cite in cluster:
                        if isinstance(cite, dict) and 'id' in cite:
                            keys.append(f'"{cite["id"]}"')
                    if keys:
                        cite_calls.append(f'#multicite({", ".join(keys)})')
        else:
            # Fallback: each input item is a separate citation
            for item in fixture.input_data:
                key = item.get('id', 'ITEM-1')
                cite_calls.append(f'#cite(<{key}>, form: "prose")')

        cite_calls_str = '\n'.join(cite_calls)
        body = f'''// Citation mode - rendered with prose form for HTML compatibility
{cite_calls_str}

// Need bibliography at end for architecture
#csl-bibliography(title: none)'''

    return f'''// Test: {fixture.name}
// Simplified test for HTML export
#import "/lib.typ": csl-bibliography, init-csl-json, multicite

#show: init-csl-json.with(
  read("/{json_path}"),
  read("/{csl_path}"){abbrevs_param},
)

{body}
'''


# =============================================================================
# Test Runner
# =============================================================================

def run_test(fixture: TestFixture, project_dir: Path, temp_dir: Path,
             compare: bool = False) -> Dict[str, Any]:
    """Run a single test and return results."""

    result = {
        'name': fixture.name,
        'mode': fixture.mode,
        'status': 'unknown',
        'expected': fixture.result,
        'actual': None,
        'error': None,
        'match': None,
    }

    csl_content = fixture.csl
    csl_content = apply_csl_patch(fixture.name, csl_content)

    # Handle citation mode without bibliography
    is_citation_mode = fixture.mode.startswith('citation')
    if is_citation_mode and '<bibliography' not in fixture.csl:
        minimal_bib = '''
  <bibliography>
    <layout>
      <text variable="title"/>
    </layout>
  </bibliography>
'''
        csl_content = csl_content.replace('</style>', minimal_bib + '</style>')

    try:
        # Write CSL-JSON
        normalized_items = normalize_csl_json(fixture.input_data)
        json_path = temp_dir / f'{fixture.name}.json'
        json_path.write_text(json.dumps(normalized_items, ensure_ascii=False, indent=2), encoding='utf-8')

        # Write CSL
        csl_path = temp_dir / f'{fixture.name}.csl'
        csl_path.write_text(csl_content, encoding='utf-8')

        # Write abbreviations if present
        abbrevs_path = None
        if fixture.abbreviations:
            abbrevs_file = temp_dir / f'{fixture.name}.abbrevs.json'
            abbrevs_file.write_text(json.dumps(fixture.abbreviations, ensure_ascii=False, indent=2), encoding='utf-8')
            abbrevs_path = str(abbrevs_file.relative_to(project_dir))

        # Generate Typst test
        test_content = generate_typst_test(
            fixture,
            str(json_path.relative_to(project_dir)),
            str(csl_path.relative_to(project_dir)),
            csl_content,
            abbrevs_path=abbrevs_path,
        )
        test_path = temp_dir / f'{fixture.name}.typ'
        test_path.write_text(test_content, encoding='utf-8')

        # Compile to HTML
        # Note: --input use-footnote=false disables footnotes to avoid HTML export convergence issues
        html_path = temp_dir / f'{fixture.name}.html'
        proc = subprocess.run(
            ['typst', 'compile', str(test_path), str(html_path),
             '--root', str(project_dir), '--format', 'html', '--features', 'html',
             '--input', 'use-footnote=false'],
            capture_output=True,
            text=True,
            timeout=30,
        )

        if proc.returncode != 0:
            # Filter out warnings, only report actual errors
            stderr_lines = [l for l in proc.stderr.split('\n')
                           if l.strip() and not l.strip().startswith(('warning:', '='))]
            if stderr_lines or proc.returncode != 0:
                result['status'] = 'error'
                result['error'] = '\n'.join(stderr_lines)[:500] if stderr_lines else f'Exit code {proc.returncode}'
                return result

        result['status'] = 'compiled'

        # Extract and compare if requested
        if compare and html_path.exists():
            html_content = html_path.read_text(encoding='utf-8')
            actual = extract_output_from_html(html_content, fixture.mode)
            result['actual'] = actual

            # Normalize for comparison - strip HTML tags from both
            # Expected may contain HTML tags like <i>, <b>, <span> etc.
            expected_normalized = re.sub(r'<[^>]+>', '', fixture.result).strip()
            actual_normalized = actual.strip()

            # Normalize whitespace
            expected_normalized = ' '.join(expected_normalized.split())
            actual_normalized = ' '.join(actual_normalized.split())

            # Simple comparison (can be made more sophisticated)
            result['match'] = expected_normalized == actual_normalized
            if result['match']:
                result['status'] = 'pass'
            else:
                result['status'] = 'mismatch'

    except subprocess.TimeoutExpired:
        result['status'] = 'timeout'
        result['error'] = 'Compilation timed out'
    except Exception as e:
        result['status'] = 'error'
        result['error'] = str(e)

    return result


# =============================================================================
# Report Generation
# =============================================================================

def generate_report(results: List[Dict[str, Any]], output_path: Path, compare: bool = False):
    """Generate a compatibility report."""

    by_category = defaultdict(list)
    for r in results:
        category = r['name'].split('_')[0]
        by_category[category].append(r)

    status_counts = defaultdict(int)
    for r in results:
        status_counts[r['status']] += 1

    total = len(results)

    report = []
    report.append('# CSL Test Suite Compatibility Report')
    report.append('')
    report.append(f'**Total Tests:** {total}')
    report.append(f'**Compare Mode:** {"enabled" if compare else "disabled"}')
    report.append('')
    report.append('## Summary by Status')
    report.append('')
    report.append('| Status | Count | Percentage |')
    report.append('|--------|-------|------------|')
    for status, count in sorted(status_counts.items()):
        pct = count * 100 / total if total > 0 else 0
        report.append(f'| {status} | {count} | {pct:.1f}% |')

    report.append('')
    report.append('## Summary by Category')
    report.append('')

    if compare:
        report.append('| Category | Total | Pass | Mismatch | Error |')
        report.append('|----------|-------|------|----------|-------|')
        for category in sorted(by_category.keys()):
            cat_results = by_category[category]
            cat_total = len(cat_results)
            passed = sum(1 for r in cat_results if r['status'] == 'pass')
            mismatch = sum(1 for r in cat_results if r['status'] == 'mismatch')
            errors = sum(1 for r in cat_results if r['status'] == 'error')
            report.append(f'| {category} | {cat_total} | {passed} | {mismatch} | {errors} |')
    else:
        report.append('| Category | Total | Compiled | Error |')
        report.append('|----------|-------|----------|-------|')
        for category in sorted(by_category.keys()):
            cat_results = by_category[category]
            cat_total = len(cat_results)
            compiled = sum(1 for r in cat_results if r['status'] == 'compiled')
            errors = sum(1 for r in cat_results if r['status'] == 'error')
            report.append(f'| {category} | {cat_total} | {compiled} | {errors} |')

    # Show mismatches if in compare mode
    if compare:
        mismatch_tests = [r for r in results if r['status'] == 'mismatch']
        if mismatch_tests:
            report.append('')
            report.append('## Mismatched Tests')
            report.append('')
            for r in mismatch_tests[:20]:
                report.append(f'### `{r["name"]}`')
                report.append('')
                report.append('**Expected:**')
                report.append('```')
                report.append(r['expected'][:200])
                report.append('```')
                report.append('')
                report.append('**Actual:**')
                report.append('```')
                report.append(str(r['actual'])[:200] if r['actual'] else '(none)')
                report.append('```')
                report.append('')
            if len(mismatch_tests) > 20:
                report.append(f'... and {len(mismatch_tests) - 20} more')

    # Show errors
    error_tests = [r for r in results if r['status'] == 'error']
    if error_tests:
        report.append('')
        report.append('## Failed Tests (Errors)')
        report.append('')
        for r in error_tests[:20]:
            report.append(f'### `{r["name"]}`')
            report.append('')
            report.append('```')
            report.append(r['error'][:300] if r['error'] else 'Unknown error')
            report.append('```')
            report.append('')
        if len(error_tests) > 20:
            report.append(f'... and {len(error_tests) - 20} more')

    output_path.write_text('\n'.join(report), encoding='utf-8')
    print(f'Report written to {output_path}')


# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(description='Run CSL test-suite against citrus')
    parser.add_argument('--limit', type=int, default=0, help='Limit number of tests')
    parser.add_argument('--category', type=str, help='Test only specific category')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    parser.add_argument('--compare', '-c', action='store_true', help='Compare output with expected')
    parser.add_argument('--source', type=str, default='test-suite',
                        choices=['test-suite', 'citeproc-js'],
                        help='Which fixture source to use')
    args = parser.parse_args()

    project_dir = Path(__file__).parent.parent.resolve()

    if args.source == 'test-suite':
        fixtures_dir = project_dir / 'references' / 'test-suite' / 'processor-tests' / 'humans'
    else:
        fixtures_dir = project_dir / 'references' / 'citeproc-js' / 'fixtures' / 'local'

    if not fixtures_dir.exists():
        print(f'Error: Fixtures directory not found: {fixtures_dir}')
        sys.exit(1)

    # Find all fixture files
    fixture_files = sorted(fixtures_dir.glob('*.txt'))

    if args.category:
        fixture_files = [f for f in fixture_files if f.stem.startswith(args.category)]

    if args.limit > 0:
        fixture_files = fixture_files[:args.limit]

    print(f'Found {len(fixture_files)} fixture files')

    # Parse fixtures
    fixtures = []
    for f in fixture_files:
        fixture = parse_fixture(f)
        if fixture:
            fixtures.append(fixture)

    print(f'Parsed {len(fixtures)} valid fixtures')

    # Run tests
    results = []
    temp_path = project_dir / 'build' / 'test-suite-tests'
    temp_path.mkdir(parents=True, exist_ok=True)

    for i, fixture in enumerate(fixtures):
        if args.verbose:
            print(f'[{i+1}/{len(fixtures)}] Testing {fixture.name}...', end=' ')

        result = run_test(fixture, project_dir, temp_path, compare=args.compare)
        results.append(result)

        if args.verbose:
            print(result['status'])

    # Generate report
    report_path = project_dir / 'build' / 'test-suite-report.md'
    report_path.parent.mkdir(exist_ok=True)
    generate_report(results, report_path, compare=args.compare)

    # Print summary
    print()
    print('=' * 60)
    print('Summary')
    print('=' * 60)
    status_counts = defaultdict(int)
    for r in results:
        status_counts[r['status']] += 1

    for status, count in sorted(status_counts.items()):
        print(f'  {status}: {count}')


if __name__ == '__main__':
    main()

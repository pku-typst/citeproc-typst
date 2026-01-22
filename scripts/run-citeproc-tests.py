#!/usr/bin/env python3
"""
citeproc-js Fixture Test Runner for citeproc-typst

Parses citeproc-js test fixtures, converts them to Typst format,
runs the tests, and generates a compatibility report.

Usage:
    python scripts/run-citeproc-tests.py [--limit N] [--category CATEGORY] [--verbose]
"""

import os
import sys
import re
import json
import subprocess
import tempfile
import argparse
from pathlib import Path
from dataclasses import dataclass
from typing import Optional, List, Dict, Any
from collections import defaultdict

# =============================================================================
# Fixture Parsing
# =============================================================================

@dataclass
class TestFixture:
    """Represents a single citeproc-js test fixture."""
    name: str
    mode: str  # citation, bibliography, bibliography-nosort
    result: str
    csl: str
    input_data: List[Dict[str, Any]]
    citation_items: Optional[List[Any]] = None
    citations: Optional[List[Any]] = None
    abbreviations: Optional[Dict[str, Any]] = None

def parse_fixture(filepath: Path) -> Optional[TestFixture]:
    """Parse a citeproc-js fixture file."""
    content = filepath.read_text(encoding='utf-8')

    def extract_section(name: str) -> Optional[str]:
        pattern = rf'>>===== {name} =====>>(.+?)<<===== {name} =====<<'
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

    citation_items = json.loads(citation_items_raw) if citation_items_raw else None
    citations = json.loads(citations_raw) if citations_raw else None
    abbreviations = json.loads(abbrevs_raw) if abbrevs_raw else None

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
    """Normalize CSL-JSON items (ensure all have IDs)."""
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

def generate_typst_test(fixture: TestFixture, json_path: str, csl_path: str, csl_content: str = None) -> str:
    """Generate a Typst test file for a fixture using CSL-JSON directly."""

    # Determine citation keys
    if fixture.citation_items:
        # Use citation-items order
        keys = []
        for cluster in fixture.citation_items:
            for cite in cluster:
                if isinstance(cite, dict) and 'id' in cite:
                    keys.append(cite['id'])
    else:
        # Use all items in order
        keys = [item.get('id', f'ITEM-{i+1}') for i, item in enumerate(fixture.input_data)]

    # Generate citations
    citations = ' '.join([f'@{key}' for key in keys])

    # Check if bibliography exists (use modified csl_content if provided)
    check_csl = csl_content if csl_content else fixture.csl
    has_bib = '<bibliography' in check_csl

    # Use init-csl-json for direct CSL-JSON input (no BibTeX conversion needed)
    return f'''// Auto-generated test for: {fixture.name}
#import "/lib.typ": csl-bibliography, init-csl-json

#set page(width: auto, height: auto, margin: 1em)

#show: init-csl-json.with(
  read("/{json_path}"),
  read("/{csl_path}"),
)

{citations}

{"#csl-bibliography()" if has_bib else ""}
'''


# =============================================================================
# Test Runner
# =============================================================================

def run_test(fixture: TestFixture, project_dir: Path, temp_dir: Path) -> Dict[str, Any]:
    """Run a single test and return results."""

    result = {
        'name': fixture.name,
        'mode': fixture.mode,
        'status': 'unknown',
        'expected': fixture.result,
        'actual': None,
        'error': None,
        'skipped_reason': None,
    }

    # Check for unsupported features
    if fixture.abbreviations:
        result['status'] = 'skipped'
        result['skipped_reason'] = 'Uses abbreviations (not supported)'
        return result

    # bibliography-nosort mode: just run as normal bibliography test
    # (sorting differences won't cause compile errors)

    # Note: We have partial CSL-M support, so try running these tests
    # Only check for truly unsupported CSL-M features
    # (most CSL-M features like multiple layouts, cs:institution are supported)

    # For citation-only tests without bibliography, inject a minimal one
    # This allows our architecture to work while still testing citation formatting
    csl_content = fixture.csl
    
    # Note: Some citeproc-js fixtures have malformed XML (unclosed tags)
    # citeproc-js uses a lenient hand-rolled parser that auto-closes tags
    # Typst uses strict XML parsing, so these tests will fail with XML errors
    # We accept this as a known limitation (5 fixtures affected)
    
    if fixture.mode == 'citation' and '<bibliography' not in fixture.csl:
        # Inject minimal bibliography before </style>
        minimal_bib = '''
  <bibliography>
    <layout>
      <text variable="title"/>
    </layout>
  </bibliography>
'''
        csl_content = csl_content.replace('</style>', minimal_bib + '</style>')

    try:
        # Normalize CSL-JSON (ensure all items have IDs)
        normalized_items = normalize_csl_json(fixture.input_data)

        # Write CSL-JSON file directly (no BibTeX conversion!)
        json_path = temp_dir / f'{fixture.name}.json'
        json_path.write_text(json.dumps(normalized_items, ensure_ascii=False, indent=2), encoding='utf-8')

        # Write CSL file (may have injected bibliography for citation-only tests)
        csl_path = temp_dir / f'{fixture.name}.csl'
        csl_path.write_text(csl_content, encoding='utf-8')

        # Generate Typst test file using init-csl-json
        test_content = generate_typst_test(
            fixture,
            str(json_path.relative_to(project_dir)),
            str(csl_path.relative_to(project_dir)),
            csl_content,
        )
        test_path = temp_dir / f'{fixture.name}.typ'
        test_path.write_text(test_content, encoding='utf-8')

        # Run typst compile
        pdf_path = temp_dir / f'{fixture.name}.pdf'
        proc = subprocess.run(
            ['typst', 'compile', str(test_path), str(pdf_path), '--root', str(project_dir)],
            capture_output=True,
            text=True,
            timeout=30,
        )

        if proc.returncode != 0:
            result['status'] = 'error'
            result['error'] = proc.stderr[:500]
            return result

        # For now, just check if it compiles (we can't easily compare HTML output with PDF)
        result['status'] = 'compiled'
        result['actual'] = '(PDF generated - manual comparison needed)'

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

def generate_report(results: List[Dict[str, Any]], output_path: Path):
    """Generate a compatibility report."""

    # Categorize results
    by_category = defaultdict(list)
    for r in results:
        category = r['name'].split('_')[0]
        by_category[category].append(r)

    # Count by status
    status_counts = defaultdict(int)
    for r in results:
        status_counts[r['status']] += 1

    total = len(results)

    report = []
    report.append('# citeproc-typst Compatibility Report')
    report.append('')
    report.append(f'**Total Tests:** {total}')
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
    report.append('| Category | Total | Compiled | Skipped | Error |')
    report.append('|----------|-------|----------|---------|-------|')

    for category in sorted(by_category.keys()):
        cat_results = by_category[category]
        cat_total = len(cat_results)
        compiled = sum(1 for r in cat_results if r['status'] == 'compiled')
        skipped = sum(1 for r in cat_results if r['status'] == 'skipped')
        errors = sum(1 for r in cat_results if r['status'] == 'error')
        report.append(f'| {category} | {cat_total} | {compiled} | {skipped} | {errors} |')

    report.append('')
    report.append('## Skipped Tests (Feature Gaps)')
    report.append('')

    skip_reasons = defaultdict(list)
    for r in results:
        if r['status'] == 'skipped':
            skip_reasons[r['skipped_reason']].append(r['name'])

    for reason, names in sorted(skip_reasons.items()):
        report.append(f'### {reason} ({len(names)} tests)')
        report.append('')
        for name in names[:5]:
            report.append(f'- `{name}`')
        if len(names) > 5:
            report.append(f'- ... and {len(names) - 5} more')
        report.append('')

    report.append('## Failed Tests (Errors)')
    report.append('')

    error_tests = [r for r in results if r['status'] == 'error']
    if error_tests:
        for r in error_tests[:20]:
            report.append(f'### `{r["name"]}`')
            report.append('')
            report.append('```')
            report.append(r['error'][:300] if r['error'] else 'Unknown error')
            report.append('```')
            report.append('')
    else:
        report.append('No errors!')

    output_path.write_text('\n'.join(report), encoding='utf-8')
    print(f'Report written to {output_path}')


# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(description='Run citeproc-js fixtures against citeproc-typst')
    parser.add_argument('--limit', type=int, default=0, help='Limit number of tests')
    parser.add_argument('--category', type=str, help='Test only specific category')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    args = parser.parse_args()

    project_dir = Path(__file__).parent.parent.resolve()
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

    # Run tests - use build/tests inside project so Typst can access files
    results = []
    temp_path = project_dir / 'build' / 'citeproc-tests'
    temp_path.mkdir(parents=True, exist_ok=True)

    for i, fixture in enumerate(fixtures):
        if args.verbose:
            print(f'[{i+1}/{len(fixtures)}] Testing {fixture.name}...', end=' ')

        result = run_test(fixture, project_dir, temp_path)
        results.append(result)

        if args.verbose:
            print(result['status'])

    # Generate report
    report_path = project_dir / 'build' / 'citeproc-compatibility-report.md'
    report_path.parent.mkdir(exist_ok=True)
    generate_report(results, report_path)

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

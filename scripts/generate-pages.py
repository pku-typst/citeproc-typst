#!/usr/bin/env python3
"""
Generate GitHub Pages index.html from test results.

Usage:
    python scripts/generate-pages.py \
        --csl-total 100 --csl-passed 95 --csl-failed 5 \
        --citeproc-total 594 --citeproc-compiled 594 --citeproc-errors 0 \
        --results-dir docs/results \
        --categories-file build/citeproc-categories.json \
        --template .github/pages/index.html \
        --output docs/index.html
"""

import argparse
import json
from pathlib import Path
from datetime import datetime, timezone


def main():
    parser = argparse.ArgumentParser(description="Generate GitHub Pages index.html")

    # CSL compatibility results
    parser.add_argument("--csl-total", type=int, required=True)
    parser.add_argument("--csl-passed", type=int, required=True)
    parser.add_argument("--csl-failed", type=int, required=True)

    # citeproc-js test results
    parser.add_argument("--citeproc-total", type=int, required=True)
    parser.add_argument("--citeproc-compiled", type=int, required=True)
    parser.add_argument("--citeproc-errors", type=int, required=True)

    # Paths
    parser.add_argument("--results-dir", type=Path, required=True,
                        help="Directory containing CSL test result PDFs")
    parser.add_argument("--categories-file", type=Path, required=True,
                        help="JSON file with citeproc category breakdown")
    parser.add_argument("--template", type=Path, required=True,
                        help="HTML template file")
    parser.add_argument("--output", type=Path, required=True,
                        help="Output HTML file")

    args = parser.parse_args()

    # Calculate rates
    csl_rate = round(args.csl_passed * 100 / args.csl_total, 1) if args.csl_total > 0 else 0
    citeproc_rate = round(args.citeproc_compiled * 100 / args.citeproc_total, 1) if args.citeproc_total > 0 else 0

    # Build time
    build_time = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    # Generate styles list HTML
    styles_html = ""
    if args.results_dir.exists():
        for pdf in sorted(args.results_dir.glob("*.pdf")):
            name = pdf.stem.replace("_", " ")
            styles_html += f'    <a href="results/{pdf.name}" class="style-link">📄 {name}</a>\n'

    # Generate citeproc categories HTML
    categories_html = ""
    if args.categories_file.exists():
        with open(args.categories_file) as f:
            categories = json.load(f)
        for cat in categories:
            categories_html += (
                f'<div class="category-item">'
                f'<span class="category-name">{cat["name"]}</span>'
                f'<span class="category-count">{cat["compiled"]}/{cat["total"]}</span>'
                f'</div>\n'
            )

    # Read template
    with open(args.template) as f:
        content = f.read()

    # Replace placeholders
    replacements = {
        "{{TOTAL}}": str(args.csl_total),
        "{{PASSED}}": str(args.csl_passed),
        "{{FAILED}}": str(args.csl_failed),
        "{{RATE}}": str(csl_rate),
        "{{BUILD_TIME}}": build_time,
        "{{STYLES_LIST}}": styles_html,
        "{{CITEPROC_TOTAL}}": str(args.citeproc_total),
        "{{CITEPROC_COMPILED}}": str(args.citeproc_compiled),
        "{{CITEPROC_ERRORS}}": str(args.citeproc_errors),
        "{{CITEPROC_RATE}}": str(citeproc_rate),
        "{{CITEPROC_CATEGORIES}}": categories_html,
    }

    for placeholder, value in replacements.items():
        content = content.replace(placeholder, value)

    # Write output
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w") as f:
        f.write(content)

    print(f"Generated {args.output}")
    print(f"  CSL: {args.csl_passed}/{args.csl_total} ({csl_rate}%)")
    print(f"  citeproc: {args.citeproc_compiled}/{args.citeproc_total} ({citeproc_rate}%)")


if __name__ == "__main__":
    main()

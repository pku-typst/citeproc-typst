#!/usr/bin/env python3
"""
Generate data.json for Astro docs site.

Combines:
- CSL compatibility results
- citeproc-js test results
- Benchmark history

Usage:
    python scripts/generate-data.py \
        --csl-total 150 --csl-passed 150 --csl-failed 0 \
        --citeproc-total 1000 --citeproc-compiled 950 --citeproc-errors 50 \
        --results-dir docs-src/public/results \
        --categories-file build/citeproc-categories.json \
        --benchmark-file build/benchmark-results.json \
        --history-file docs-src/public/history.json \
        --output docs-src/public/data.json
"""

import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path


def load_json(path: Path, default=None):
    """Load JSON file with fallback."""
    if path.exists():
        with open(path) as f:
            return json.load(f)
    return default


def update_history(history: dict, benchmark: dict, max_runs: int = 50) -> dict:
    """Add new benchmark run to history."""
    if not benchmark or "results" not in benchmark:
        return history

    # Add new run
    history["runs"].append({
        "date": benchmark.get("date", datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")),
        "commit": benchmark.get("commit", "unknown")[:7],
        "results": benchmark["results"]
    })

    # Update styles list
    history["styles"] = list(benchmark["results"].keys())

    # Keep only recent runs
    history["runs"] = history["runs"][-max_runs:]

    return history


def get_styles_from_results(results_dir: Path) -> list:
    """Get list of styles from PDF results directory."""
    styles = []
    if results_dir.exists():
        for pdf in sorted(results_dir.glob("*.pdf")):
            name = pdf.stem.replace("__", "/").replace("_", " ")
            styles.append({
                "name": name,
                "url": f"results/{pdf.name}"
            })
    return styles


def main():
    parser = argparse.ArgumentParser(description="Generate data.json for docs")

    # CSL compatibility args
    parser.add_argument("--csl-total", type=int, default=0)
    parser.add_argument("--csl-passed", type=int, default=0)
    parser.add_argument("--csl-failed", type=int, default=0)
    parser.add_argument("--results-dir", type=Path, default=Path("docs-src/public/results"))

    # Benchmark args
    parser.add_argument("--benchmark-file", type=Path, default=Path("build/benchmark-results.json"))
    parser.add_argument("--history-file", type=Path, default=Path("docs-src/public/history.json"))
    parser.add_argument("--max-history", type=int, default=50)

    # Test suite report
    parser.add_argument("--test-suite-file", type=Path, default=Path("build/test-suite-report.json"))

    # Output
    parser.add_argument("--output", type=Path, default=Path("docs-src/public/data.json"))

    args = parser.parse_args()

    # Load existing history
    history = load_json(args.history_file, {"runs": [], "styles": []})

    # Load new benchmark results
    benchmark = load_json(args.benchmark_file)

    # Update history with new benchmark
    history = update_history(history, benchmark, args.max_history)

    # Save updated history
    args.history_file.parent.mkdir(parents=True, exist_ok=True)
    with open(args.history_file, "w") as f:
        json.dump(history, f, indent=2)

    # Load test-suite report
    test_suite = load_json(args.test_suite_file, {
        "summary": {"total": 0, "pass": 0, "mismatch": 0, "excluded": 0, "error": 0},
        "byCategory": [],
        "mismatches": [],
        "excluded": [],
        "errors": [],
    })

    # Get styles list from results
    styles = get_styles_from_results(args.results_dir)

    # Build final data
    data = {
        "csl": {
            "total": args.csl_total,
            "passed": args.csl_passed,
            "failed": args.csl_failed,
            "styles": styles
        },
        "testSuite": test_suite,
        "benchmark": history,
        "buildTime": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    }

    # Write output
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w") as f:
        json.dump(data, f, indent=2)

    print(f"Generated {args.output}")
    print(f"  CSL styles: {len(styles)}")
    print(f"  Categories: {len(categories)}")
    print(f"  Benchmark runs: {len(history['runs'])}")


if __name__ == "__main__":
    main()

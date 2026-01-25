#!/usr/bin/env python3
"""
Analyze CSL files for complexity metrics.

Metrics:
- Number of macro definitions
- Maximum nesting depth
- Total nodes count
- Macro call count

Usage:
    python scripts/analyze-csl-complexity.py /path/to/styles/src [--bottom]
"""

import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from dataclasses import dataclass


@dataclass
class CslMetrics:
    name: str
    macro_count: int
    max_depth: int
    total_nodes: int
    macro_calls: int
    file_size: int


def get_max_depth(element, current_depth=0):
    """Recursively calculate maximum nesting depth."""
    max_child_depth = current_depth
    for child in element:
        child_depth = get_max_depth(child, current_depth + 1)
        max_child_depth = max(max_child_depth, child_depth)
    return max_child_depth


def count_nodes(element):
    """Count total number of XML nodes."""
    count = 1
    for child in element:
        count += count_nodes(child)
    return count


def count_macro_calls(element, ns):
    """Count number of macro calls (<text macro="..."/>)."""
    count = 0
    # Check for text elements with macro attribute
    for text_elem in element.iter(f"{{{ns}}}text"):
        if "macro" in text_elem.attrib:
            count += 1
    return count


def analyze_csl(filepath: Path) -> CslMetrics:
    """Analyze a single CSL file."""
    try:
        tree = ET.parse(filepath)
        root = tree.getroot()

        # Extract namespace
        ns = root.tag.split("}")[0].strip("{") if "}" in root.tag else ""

        # Count macros
        macros = root.findall(f".//{{{ns}}}macro") if ns else root.findall(".//macro")
        macro_count = len(macros)

        # Calculate max depth
        max_depth = get_max_depth(root)

        # Count total nodes
        total_nodes = count_nodes(root)

        # Count macro calls
        macro_calls = count_macro_calls(root, ns)

        return CslMetrics(
            name=filepath.stem,
            macro_count=macro_count,
            max_depth=max_depth,
            total_nodes=total_nodes,
            macro_calls=macro_calls,
            file_size=filepath.stat().st_size,
        )
    except Exception as e:
        print(f"Error parsing {filepath}: {e}", file=sys.stderr)
        return None


def complexity_score(m):
    return m.macro_count * 2 + m.max_depth * 3 + m.macro_calls + m.total_nodes / 100


def main():
    if len(sys.argv) < 2:
        print("Usage: python analyze-csl-complexity.py /path/to/styles/src [--bottom]")
        sys.exit(1)

    styles_dir = Path(sys.argv[1])
    show_bottom = "--bottom" in sys.argv

    csl_files = list(styles_dir.glob("**/*.csl"))

    print(f"Analyzing {len(csl_files)} CSL files...\n")

    metrics = []
    for csl_file in csl_files:
        m = analyze_csl(csl_file)
        if m:
            metrics.append(m)

    if show_bottom:
        print("=" * 80)
        print("BOTTOM 10 BY COMBINED COMPLEXITY SCORE (simplest)")
        print("=" * 80)
        for m in sorted(metrics, key=complexity_score)[:10]:
            score = complexity_score(m)
            print(f"  score {score:6.1f} | macros:{m.macro_count:2d} depth:{m.max_depth:2d} calls:{m.macro_calls:3d} | {m.name}")
    else:
        # Sort by different criteria
        print("=" * 80)
        print("TOP 10 BY MACRO COUNT")
        print("=" * 80)
        for m in sorted(metrics, key=lambda x: x.macro_count, reverse=True)[:10]:
            print(f"  {m.macro_count:3d} macros | {m.name}")

        print("\n" + "=" * 80)
        print("TOP 10 BY MAX NESTING DEPTH")
        print("=" * 80)
        for m in sorted(metrics, key=lambda x: x.max_depth, reverse=True)[:10]:
            print(f"  depth {m.max_depth:2d} | {m.name}")

        print("\n" + "=" * 80)
        print("TOP 10 BY TOTAL NODES")
        print("=" * 80)
        for m in sorted(metrics, key=lambda x: x.total_nodes, reverse=True)[:10]:
            print(f"  {m.total_nodes:4d} nodes | {m.name}")

        print("\n" + "=" * 80)
        print("TOP 10 BY MACRO CALLS")
        print("=" * 80)
        for m in sorted(metrics, key=lambda x: x.macro_calls, reverse=True)[:10]:
            print(f"  {m.macro_calls:3d} calls | {m.name}")

        print("\n" + "=" * 80)
        print("TOP 10 BY FILE SIZE")
        print("=" * 80)
        for m in sorted(metrics, key=lambda x: x.file_size, reverse=True)[:10]:
            print(f"  {m.file_size:6d} bytes | {m.name}")

        # Combined score (normalized)
        print("\n" + "=" * 80)
        print("TOP 15 BY COMBINED COMPLEXITY SCORE")
        print("(macro_count * 2 + max_depth * 3 + macro_calls + total_nodes/100)")
        print("=" * 80)

        for m in sorted(metrics, key=complexity_score, reverse=True)[:15]:
            score = complexity_score(m)
            print(f"  score {score:6.1f} | macros:{m.macro_count:2d} depth:{m.max_depth:2d} calls:{m.macro_calls:3d} | {m.name}")


if __name__ == "__main__":
    main()

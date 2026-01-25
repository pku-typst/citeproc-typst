#!/bin/bash
#
# Benchmark representative CSL styles
# Outputs: build/benchmark-results.json
#
# Styles selected based on complexity analysis (scripts/analyze-csl-complexity.py):
# - High complexity: 90 macros, depth 14, 220 macro calls
# - Medium complexity: 55 macros, depth 11
# - Low complexity: 12 macros, depth 7
# - Baseline: 12 macros, depth 6
#
set -e

RUNS=3  # Number of runs per style (take median)
RESULTS_FILE="build/benchmark-results.json"
STYLES_DIR="${STYLES_DIR:-zotero-chinese-styles/src}"

mkdir -p build

# Helper function to get time in milliseconds (cross-platform)
get_time_ms() {
  python3 -c "import time; print(int(time.time() * 1000))"
}

# Benchmark a single style
# Arguments: $1 = display name, $2 = CSL file path
# Returns: median time in ms (or empty on failure)
benchmark_style() {
  local name="$1"
  local csl_file="$2"

  if [[ ! -f "$csl_file" ]]; then
    echo "⚠ $name not found at $csl_file, skipping" >&2
    return 1
  fi

  # Run N times, collect times
  local times=()
  for i in $(seq 1 $RUNS); do
    local start=$(get_time_ms)
    if typst compile tests/csl-compatibility/test.typ /tmp/bench.pdf \
        --root . --font-path fonts/ --input "csl=$csl_file" 2>/dev/null; then
      local end=$(get_time_ms)
      times+=($((end - start)))
    else
      echo "✗ $name failed to compile" >&2
      return 1
    fi
  done

  # Calculate median
  IFS=$'\n' sorted=($(sort -n <<<"${times[*]}")); unset IFS
  local median=${sorted[$((RUNS / 2))]}

  echo "✓ $name: ${median}ms (runs: ${times[*]})" >&2
  echo "$median"
}

# Start JSON
echo "{" > "$RESULTS_FILE"
echo "  \"commit\": \"${GITHUB_SHA:-local}\"," >> "$RESULTS_FILE"
echo "  \"date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$RESULTS_FILE"
echo "  \"results\": {" >> "$RESULTS_FILE"

first=true
found_count=0

# Helper to add result to JSON
add_result() {
  local name="$1"
  local time="$2"

  if [[ "$first" == "true" ]]; then
    first=false
  else
    echo "," >> "$RESULTS_FILE"
  fi
  echo -n "    \"$name\": $time" >> "$RESULTS_FILE"
  ((found_count++)) || true
}

# =============================================================================
# Chinese styles from STYLES_DIR (zotero-chinese/styles)
# =============================================================================

# High complexity (score > 400) - stress test
CHINESE_STYLES=(
  "四川外国语大学-英语语言文学（语言学、教学法方向）"  # 463.6: 90 macros, depth 14
  "公共行政评论"                                      # 453.2: 87 macros, 2225 nodes
  "法学引注手册（多语言）"                            # 426.3: 243 macro calls

  # Medium complexity (score ~200-250)
  "心理学报"                                          # 241.4: 55 macros, depth 11
  "IEEE（双语）"                                      # 173.1: 13 macros, 116 calls

  # Low complexity (score < 100)
  "微生物学报"                                        # 67.7: 12 macros, depth 7
  "food-materials-research"                           # 66.8: 9 macros, English

  # Baseline (simplest real style)
  "马克思主义研究"                                    # 59.2: 12 macros, depth 6
)

for style in "${CHINESE_STYLES[@]}"; do
  csl_file="${STYLES_DIR}/${style}/${style}.csl"

  # Fallback: search if exact path doesn't exist
  if [[ ! -f "$csl_file" ]]; then
    csl_file=$(find "$STYLES_DIR" -name "${style}.csl" 2>/dev/null | head -1)
  fi

  if [[ -z "$csl_file" || ! -f "$csl_file" ]]; then
    echo "⚠ Style $style not found, skipping"
    continue
  fi

  result=$(benchmark_style "$style" "$csl_file" | tail -1)
  if [[ "$result" =~ ^[0-9]+$ ]]; then
    add_result "$style" "$result"
  fi
done

# =============================================================================
# English styles from examples/ directory
# =============================================================================

# Chicago (high complexity English style)
# score=246.7: 57 macros, depth 13, 87 calls
if [[ -f "examples/chicago-fullnote-bibliography.csl" ]]; then
  result=$(benchmark_style "chicago-fullnote-bibliography" "examples/chicago-fullnote-bibliography.csl" | tail -1)
  if [[ "$result" =~ ^[0-9]+$ ]]; then
    add_result "chicago-fullnote-bibliography" "$result"
  fi
fi

# Close JSON
echo "" >> "$RESULTS_FILE"
echo "  }" >> "$RESULTS_FILE"
echo "}" >> "$RESULTS_FILE"

echo ""
echo "Benchmark complete: $found_count styles tested"
echo "Results: $RESULTS_FILE"

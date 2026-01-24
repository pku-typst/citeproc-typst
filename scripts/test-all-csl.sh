#!/bin/bash
#
# CSL Compatibility Test Script
#
# Tests all CSL files for compatibility with citeproc-typst.
#
# Usage: ./scripts/test-all-csl.sh [--verbose] [--limit N] [--styles-dir DIR]
#
# By default, looks for CSL files in:
#   1. references/styles/src (local development)
#   2. zotero-styles/src (CI environment)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/build/csl-tests"

# Find styles directory
if [ -d "$PROJECT_DIR/references/styles/src" ]; then
  STYLES_DIR="$PROJECT_DIR/references/styles/src"
elif [ -d "$PROJECT_DIR/zotero-styles/src" ]; then
  STYLES_DIR="$PROJECT_DIR/zotero-styles/src"
else
  echo "Error: No CSL styles directory found."
  echo "Expected: references/styles/src or zotero-styles/src"
  exit 1
fi

# Parse arguments
VERBOSE=false
LIMIT=0
CUSTOM_STYLES_DIR=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --limit|-l)
      LIMIT=$2
      shift 2
      ;;
    --styles-dir|-s)
      CUSTOM_STYLES_DIR=$2
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -v, --verbose        Show detailed error messages"
      echo "  -l, --limit N        Test only first N styles"
      echo "  -s, --styles-dir DIR Use custom styles directory"
      echo "  -h, --help           Show this help"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Override styles directory if custom one provided
if [ -n "$CUSTOM_STYLES_DIR" ]; then
  if [ -d "$CUSTOM_STYLES_DIR" ]; then
    STYLES_DIR="$CUSTOM_STYLES_DIR"
  else
    echo "Error: Specified styles directory does not exist: $CUSTOM_STYLES_DIR"
    exit 1
  fi
fi

echo "Using styles from: $STYLES_DIR"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Find all CSL files
CSL_FILES=$(find "$STYLES_DIR" -name "*.csl" | sort)
TOTAL=$(echo "$CSL_FILES" | wc -l | tr -d ' ')

echo "=============================================="
echo "CSL Compatibility Test for citeproc-typst"
echo "=============================================="
echo "Found $TOTAL CSL files"
echo ""

# Counters
PASSED=0
FAILED=0
SKIPPED=0
COUNT=0

# Results file
RESULTS_FILE="$OUTPUT_DIR/results.txt"
FAILED_FILE="$OUTPUT_DIR/failed.txt"
TIMING_FILE="$OUTPUT_DIR/timing.txt"
echo "Test Results - $(date)" > "$RESULTS_FILE"
echo "" > "$FAILED_FILE"
echo "" > "$TIMING_FILE"

# Test each CSL file
while IFS= read -r csl_file; do
  COUNT=$((COUNT + 1))

  # Check limit
  if [ "$LIMIT" -gt 0 ] && [ "$COUNT" -gt "$LIMIT" ]; then
    break
  fi

  # Get relative path for display and for Typst
  REL_PATH="${csl_file#$PROJECT_DIR/}"
  NAME=$(basename "$csl_file" .csl)

  # Progress indicator
  printf "[%3d/%3d] Testing: %s... " "$COUNT" "$TOTAL" "$NAME"

  # Create output path
  SAFE_NAME=$(echo "$NAME" | tr ' /' '__' | head -c 100)
  OUTPUT_PDF="$OUTPUT_DIR/${SAFE_NAME}.pdf"

  # Run typst compile with project root set to project directory
  # Use relative path for CSL file and include fonts directory
  START_TIME=$(python3 -c 'import time; print(time.time())')
  if typst compile "$PROJECT_DIR/tests/test-csl-compatibility.typ" "$OUTPUT_PDF" \
       --root "$PROJECT_DIR" \
       --font-path "$PROJECT_DIR/fonts" \
       --input "csl=$REL_PATH" 2>"$OUTPUT_DIR/error.log"; then
    END_TIME=$(python3 -c 'import time; print(time.time())')
    ELAPSED=$(python3 -c "print(f'{$END_TIME - $START_TIME:.3f}')")
    echo "✓ PASS (${ELAPSED}s)"
    PASSED=$((PASSED + 1))
    echo "PASS: $REL_PATH (${ELAPSED}s)" >> "$RESULTS_FILE"
    echo "${ELAPSED} $NAME" >> "$OUTPUT_DIR/timing.txt"
  else
    END_TIME=$(python3 -c 'import time; print(time.time())')
    ELAPSED=$(python3 -c "print(f'{$END_TIME - $START_TIME:.3f}')")
    echo "✗ FAIL (${ELAPSED}s)"
    FAILED=$((FAILED + 1))
    echo "FAIL: $REL_PATH (${ELAPSED}s)" >> "$RESULTS_FILE"
    echo "$REL_PATH" >> "$FAILED_FILE"
    echo "${ELAPSED} $NAME (FAIL)" >> "$OUTPUT_DIR/timing.txt"

    if [ "$VERBOSE" = true ]; then
      echo "  Error:"
      cat "$OUTPUT_DIR/error.log" | head -20 | sed 's/^/    /'
    fi
  fi
done <<< "$CSL_FILES"

# Summary
echo ""
echo "=============================================="
echo "Summary"
echo "=============================================="
echo "Total:   $COUNT"
echo "Passed:  $PASSED"
echo "Failed:  $FAILED"
echo "Skipped: $((TOTAL - COUNT))"
echo ""
echo "Pass Rate: $(echo "scale=1; $PASSED * 100 / $COUNT" | bc)%"
echo ""
echo "Results saved to: $RESULTS_FILE"

if [ "$FAILED" -gt 0 ]; then
  echo "Failed styles saved to: $FAILED_FILE"
  echo ""
  echo "First 10 failures:"
  head -10 "$FAILED_FILE" | sed 's/^/  /'
fi

echo ""
echo "Top 20 slowest CSL files:"
sort -rn "$TIMING_FILE" | head -20 | sed 's/^/  /'
echo ""
echo "Timing data saved to: $TIMING_FILE"

# Exit with error if any failed
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi

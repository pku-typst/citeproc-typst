# citeproc-typst development tasks

set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]
set shell := ["bash", "-cu"]

# =============================================================================
# Build & Development
# =============================================================================

[unix]
pre-commit:
    @if command -v prek > /dev/null 2>&1; then prek run --all-files; else pre-commit run --all-files; fi

[windows]
pre-commit:
    if (Get-Command prek -ErrorAction SilentlyContinue) { prek run --all-files } else { pre-commit run --all-files }

# Compile English example
build-en:
    typst compile examples/example-en.typ build/example-en.pdf --root . --font-path fonts/

# Compile Chinese example
build-zh:
    typst compile examples/example-zh.typ build/example-zh.pdf --root . --font-path fonts/

# Build all examples
build: build-en build-zh

# Watch English example
watch-en:
    typst watch examples/example-en.typ build/example-en.pdf --root . --font-path fonts/

# Watch Chinese example
watch-zh:
    typst watch examples/example-zh.typ build/example-zh.pdf --root . --font-path fonts/

# Run all unit tests with tytanic
test:
    tt run --font-path fonts/

# Update test references (after intentional changes)
test-update:
    tt update --font-path fonts/ --force

# Run specific test
test-one name:
    tt run --font-path fonts/ {{name}}

# Run CSL compatibility tests (requires styles in references/styles/src)
test-csl:
    ./scripts/test-all-csl.sh --limit 10

# Run full CSL compatibility tests
test-csl-all:
    ./scripts/test-all-csl.sh

# Clean build artifacts
clean:
    rm -rf build/

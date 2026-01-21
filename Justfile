# citeproc-typst development tasks

# Default recipe
default:
    @just --list

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

# Run CSL compatibility tests (requires styles in references/styles/src)
test-csl:
    ./scripts/test-all-csl.sh --limit 10

# Run full CSL compatibility tests
test-csl-all:
    ./scripts/test-all-csl.sh

# Clean build artifacts
clean:
    rm -rf build/

# Run pre-commit hooks (prefer prek, fallback to pre-commit)
[unix]
pre-commit:
  @if command -v prek > /dev/null 2>&1; then prek run --all-files; else pre-commit run --all-files; fi

[windows]
pre-commit:
  @where prek >nul 2>&1 && prek run --all-files || pre-commit run --all-files

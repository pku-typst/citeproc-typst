# Development Guide

## Long-Term Memory

- Maintain a memory file at `./build/memory.md` which serves as your long-term memory.

## Key Documents

- `KNOWN-ISSUES.md` - Tracks CSL test-suite alignment progress and documents spec interpretation differences from citeproc-js.

## Testing

Run all tests:

```bash
just test
```

Run specific test:

```bash
just test-one <test-name>
```

Update test snapshots after intentional changes:

```bash
just test-update
```

## Debugging Test Failures

When a test snapshot changes unexpectedly:

1. Compile to PDF:

```bash
typst compile tests/<test-name>/test.typ build/<test-name>.pdf --root . --font-path fonts/
```

2. Extract text to inspect output:

```bash
pdftotext build/<test-name>.pdf -
```

3. Compare with expected behavior, then either fix the code or update the snapshot.

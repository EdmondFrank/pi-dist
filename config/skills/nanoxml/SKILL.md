---
name: nanoxml
description: "Fast Office Open XML (.docx/.xlsx/.pptx) reading, editing, creation, and validation using the nanoxml CLI tool. Use when working with Word documents, Excel spreadsheets, or PowerPoint presentations for: (1) Extracting text or data, (2) Creating new Office files, (3) Editing cells or document properties, (4) Validating Office files, (5) Converting between formats (CSV↔XLSX, text↔DOCX). Single static binary with zero dependencies, JSON output support, and agent-friendly design."
---

# nanoxml

Fast Office Open XML processing for humans and agents. Single static binary, zero dependencies, JSON output, stdin/stdout piping.

## Quick Start

### Installation

```bash
# One-liner (detects platform)
curl -fsSL https://justrach.github.io/nanoxml/install.sh | sh

# Or download specific binary
# macOS (Apple Silicon)
curl -fsSL -o nanoxml https://github.com/justrach/nanoxml/releases/latest/download/nanoxml-darwin-arm64
chmod +x nanoxml && sudo mv nanoxml /usr/local/bin/
```

### Basic Usage

```bash
# Read
nanoxml info report.docx --json          # Document metadata
nanoxml text report.docx                 # Extract text
nanoxml csv data.xlsx 0                  # Sheet 0 as CSV
nanoxml sheets data.xlsx --json          # List worksheets

# Write
nanoxml set-cell budget.xlsx 0 B7 1250   # Edit cell
nanoxml set-props doc.docx --title "New" # Set properties

# Create
nanoxml new docx out.docx                # New document
nanoxml from-csv data.csv out.xlsx       # CSV → XLSX
nanoxml from-text notes.txt memo.docx    # Text → DOCX

# Verify
nanoxml validate file.xlsx --json        # Check validity
```

## Command Reference

### Read Commands

| Command | Description | Output |
|---------|-------------|--------|
| `nanoxml info <file> [--json]` | Document kind, main part, sheets/slides | JSON or text |
| `nanoxml text <file>` | Extract text (docx/pptx) | Plain text |
| `nanoxml csv <file> [sheet#]` | Worksheet as CSV (xlsx) | CSV |
| `nanoxml sheets <file> [--json]` | List worksheets (xlsx) | JSON or text |
| `nanoxml parts <file> [--json]` | Parts + content types | JSON or text |
| `nanoxml dump <file> <part>` | Raw bytes of one part | Raw content |
| `nanoxml validate <file> [--json]` | Diagnostics; exit 1 if invalid | JSON |

### Write Commands

| Command | Description |
|---------|-------------|
| `nanoxml set-cell <file> <sheet#> <A1> <value> [--string\|--number]` | Edit cell value |
| `nanoxml set-props <file> [--title T] [--creator C] [--subject S] [--description D]` | Set document properties |
| `nanoxml set-part <file> <part> [content-file\|-]` | Replace part content |
| `nanoxml rm-part <file> <part>` | Remove part and relationships |
| `nanoxml roundtrip <file> <out>` | Re-serialize main part via DOM |

### Create Commands

| Command | Description |
|---------|-------------|
| `nanoxml new docx\|xlsx\|pptx <out>` | Create empty Office file |
| `nanoxml from-csv <csv-file\|-> <out.xlsx> [--sheet NAME]` | CSV → XLSX |
| `nanoxml from-text <text-file\|-> <out.docx> [--title T]` | Text → DOCX (line = paragraph) |

### Other Commands

| Command | Description |
|---------|-------------|
| `nanoxml bench <file> [iters] [full\|parse\|unzip]` | Performance benchmark |

## Workflows

### Extract and Analyze Data

```bash
# Discover sheets
nanoxml sheets book.xlsx --json

# Extract specific sheet
nanoxml csv book.xlsx 2 > sheet2.csv

# Get document info
nanoxml info report.docx --json
```

### Edit Spreadsheet Safely

```bash
# Edit with --out to avoid modifying original
nanoxml set-cell book.xlsx 0 D9 42 --out /tmp/edited.xlsx

# Validate before replacing
nanoxml validate /tmp/edited.xlsx && mv /tmp/edited.xlsx book.xlsx
```

### Surgical XML Edit

```bash
# Find the part
nanoxml parts f.docx --json

# Dump, edit, and restore
nanoxml dump f.docx word/styles.xml > s.xml
# ... edit s.xml ...
nanoxml set-part f.docx word/styles.xml s.xml
nanoxml validate f.docx
```

### Generate Report from Program Output

```bash
my-analysis --csv | nanoxml from-csv - results.xlsx --sheet Analysis
```

### Create Documents from Text

```bash
# Each line becomes a paragraph
nanoxml from-text notes.txt memo.docx --title "Meeting Notes"
```

## Contract

- **Exit codes**: `0` = success, nonzero = failure
- **JSON output**: Use `--json` on `info`, `parts`, `sheets`, `validate`
- **In-place editing**: Write commands edit in place by default; use `--out PATH` for new file
- **Stdin support**: `-` means stdin wherever content file is accepted
- **Flag flexibility**: Flags may appear anywhere in argument list

## Performance

- 200k-row xlsx → CSV in 179ms (4.7× faster than Microsoft SDK)
- 50k-paragraph docx → text in 16.7ms
- Safe to call in tight loops

## Agent Integration

nanoxml is designed for AI agents:

- Single static binary, no runtime dependencies
- `--json` output for machine parsing
- Stdin/stdout piping support
- In-place or `--out` edits
- Strict exit codes
- Self-validation command

See [references/agents-contract.md](references/agents-contract.md) for complete agent integration guide.

## Error Handling

Errors print `nanoxml: error: ` to stderr. Always check exit codes:

```bash
if nanoxml validate file.xlsx --json; then
    echo "Valid"
else
    echo "Invalid - check diagnostics"
fi
```

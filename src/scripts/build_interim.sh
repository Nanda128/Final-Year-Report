#!/usr/bin/env bash

# This script is for building a LaTeX document located in the project root directory.
# It runs pdflatex and bibtex as needed, captures logs, and organizes output files
# This script assumes that pdflatex and bibtex are installed and available in the system PATH.
# Also, don't worry about moving this script anywhere. It works out the box from this location.

# This script is for Linux/macOS users, if you are on Windows, please use the corresponding shell script in build_interim.ps1.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR"/../..)"
INTERIM_DIR="$REPO_ROOT/interim"
AUXIL_DIR="$REPO_ROOT/auxil"
LOG_DIR="$REPO_ROOT/src/scripts/log"
mkdir -p "$LOG_DIR"
mkdir -p "$AUXIL_DIR"

MAIN_TEX_FILE="interim_report.tex"
TEX_SRC="$INTERIM_DIR/$MAIN_TEX_FILE"
BIB_SRC="$INTERIM_DIR/interim_report.bib"
BIB_DEST="$REPO_ROOT/interim_report.bib"
OUTPUT_PATH="$REPO_ROOT/Interim_FYP-DT-MSAR_23070854.pdf"

# Always work in repo root
cd "$REPO_ROOT" || exit 1
# Copy .tex and .bib from interim to repo root
cp -f "$TEX_SRC" "$MAIN_TEX_FILE"
if [ -f "$BIB_SRC" ]; then
  cp -f "$BIB_SRC" "$BIB_DEST"
fi
# Copy interim/sections/ to repo root/sections
SECTIONS_SRC="$INTERIM_DIR/sections"
SECTIONS_DEST="$REPO_ROOT/sections"
if [ -d "$SECTIONS_SRC" ]; then
  rm -rf "$SECTIONS_DEST"
  cp -r "$SECTIONS_SRC" "$SECTIONS_DEST"
fi
# First pdflatex pass
pdflatex -interaction=nonstopmode -halt-on-error "$MAIN_TEX_FILE" 2>&1 | tee "$LOG_DIR/pdflatex-pass1.scripts.log"
# Bibtex if .aux exists
if [ -f "interim_report.aux" ]; then
  bibtex interim_report 2>&1 | tee "$LOG_DIR/bibtex.scripts.log"
fi
# Second and third pdflatex passes
pdflatex -interaction=nonstopmode -halt-on-error "$MAIN_TEX_FILE" 2>&1 | tee "$LOG_DIR/pdflatex-pass2.scripts.log"
pdflatex -interaction=nonstopmode -halt-on-error "$MAIN_TEX_FILE" 2>&1 | tee "$LOG_DIR/pdflatex-pass3.scripts.log"
# Move PDF and aux files
TEMP_PDF_PATH="$REPO_ROOT/interim_report.pdf"
if [ -f "$TEMP_PDF_PATH" ]; then
  mv "$TEMP_PDF_PATH" "$OUTPUT_PATH"
  for ext in aux log bbl blg; do
    f="$REPO_ROOT/interim_report.$ext"
    if [ -f "$f" ]; then
      mv "$f" "$AUXIL_DIR/"
    fi
  done
  find "$REPO_ROOT" -maxdepth 1 -type f \( -name "*.out" -o -name "*.toc" -o -name "*.bbl" -o -name "*.blg" \) -exec rm -f {} +
  # Word count logic unchanged
  PDF_WORDCOUNT=""
  if command -v pdftotext >/dev/null 2>&1; then
    RAW=$(pdftotext -layout -enc UTF-8 "$OUTPUT_PATH" - 2>/dev/null || true)
    if [ -n "$RAW" ]; then
      PDF_WORDCOUNT=$(printf "%s" "$RAW" | wc -w)
    fi
  elif command -v pdftohtml >/dev/null 2>&1; then
    RAW=$(pdftohtml -stdout -i -q "$OUTPUT_PATH" 2>/dev/null || true)
    if [ -n "$RAW" ]; then
      TEXT_ONLY=$(printf "%s" "$RAW" | sed -E 's/<[^>]*>/ /g')
      PDF_WORDCOUNT=$(printf "%s" "$TEXT_ONLY" | wc -w)
    fi
  elif command -v strings >/dev/null 2>&1; then
    RAW=$(strings "$OUTPUT_PATH" 2>/dev/null || true)
    if [ -n "$RAW" ]; then
      PDF_WORDCOUNT=$(printf "%s" "$RAW" | wc -w)
    fi
  else
    PDF_WORDCOUNT=""
  fi

  if [ -n "$PDF_WORDCOUNT" ] && [ "$PDF_WORDCOUNT" -gt 0 ]; then
    echo "Word count (PDF text): ${PDF_WORDCOUNT}/10,000"
    echo "Word count (PDF text): ${PDF_WORDCOUNT}/10,000" >> "$LOG_DIR/wordcount.scripts.log"
  else
    echo "Word count (PDF text): unavailable (no extractor found)/10,000"
  fi

  printf "Done. Output: %s. Log files cleaned up. Build logs: %s\n" "$OUTPUT_PATH" "$LOG_DIR"
else
  find "$REPO_ROOT" -maxdepth 1 -type f \( -name "*.aux" -o -name "*.log" -o -name "*.out" -o -name "*.toc" -o -name "*.bbl" -o -name "*.blg" \) -exec mv -f {} "$LOG_DIR/" \;
  echo "PDF compilation failed. Logs: $LOG_DIR"
fi

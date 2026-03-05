#!/usr/bin/env bash

# Generic LaTeX build script for Final Year Report
# This script builds a LaTeX document and supports both interim and final reports
# Usage: ./build_report.sh <report_name>
# Example: ./build_report.sh interim
# Example: ./build_report.sh final

set -o pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <report_name>"
    echo "Example: $0 interim"
    echo "Example: $0 final"
    exit 1
fi

REPORT_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORT_DIR="$REPO_ROOT/$REPORT_NAME"
AUXIL_DIR="$REPO_ROOT/auxil"
LOG_DIR="$REPO_ROOT/src/scripts/log/$REPORT_NAME"
mkdir -p "$LOG_DIR"
mkdir -p "$AUXIL_DIR"

MAIN_TEX_FILE="${REPORT_NAME}_report.tex"
TEX_SRC="$REPORT_DIR/$MAIN_TEX_FILE"

OUTPUT_PATH="$REPO_ROOT/${REPORT_NAME}_report.pdf"

if [ "$REPORT_NAME" = "interim" ]; then
    OUTPUT_PATH="$REPO_ROOT/Interim_FYP-DT-MSAR_23070854.pdf"
elif [ "$REPORT_NAME" = "final" ]; then
    OUTPUT_PATH="$REPO_ROOT/Final_FYP-DT-MSAR_23070854.pdf"
fi

if [ ! -d "$REPORT_DIR" ]; then
  echo "Report directory not found: $REPORT_DIR" >&2
  exit 1
fi
if [ ! -f "$TEX_SRC" ]; then
  echo "Main TeX file not found: $TEX_SRC" >&2
  exit 1
fi

cd "$REPORT_DIR" || exit 1

pdflatex -interaction=nonstopmode -halt-on-error "$MAIN_TEX_FILE" 2>&1 | tee "$LOG_DIR/pdflatex-pass1.scripts.log"

if [ -f "${REPORT_NAME}_report.aux" ]; then
  bibtex "${REPORT_NAME}_report" 2>&1 | tee "$LOG_DIR/bibtex.scripts.log"
fi

pdflatex -interaction=nonstopmode -halt-on-error "$MAIN_TEX_FILE" 2>&1 | tee "$LOG_DIR/pdflatex-pass2.scripts.log"
pdflatex -interaction=nonstopmode -halt-on-error "$MAIN_TEX_FILE" 2>&1 | tee "$LOG_DIR/pdflatex-pass3.scripts.log"

TEMP_PDF_PATH="$REPORT_DIR/${REPORT_NAME}_report.pdf"
if [ -f "$TEMP_PDF_PATH" ]; then
  mv "$TEMP_PDF_PATH" "$OUTPUT_PATH"
  for ext in aux log bbl blg; do
    f="$REPORT_DIR/${REPORT_NAME}_report.$ext"
    if [ -f "$f" ]; then
      mv "$f" "$LOG_DIR/"
    fi
  done
  find "$REPORT_DIR" -maxdepth 1 -type f \( -name "*.out" -o -name "*.toc" -o -name "*.bbl" -o -name "*.blg" -o -name "*.brf" \) -exec rm -f {} +

  if [ -d "$REPORT_DIR/sections" ]; then
    find "$REPORT_DIR/sections" -type f \( -name "*.out" -o -name "*.brf" \) -exec rm -f {} +
  fi

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
  find "$REPORT_DIR" -maxdepth 1 -type f \( -name "*.aux" -o -name "*.log" -o -name "*.out" -o -name "*.toc" -o -name "*.bbl" -o -name "*.blg" \) -exec mv -f {} "$LOG_DIR/" \;
  echo "PDF compilation failed. Logs: $LOG_DIR"
fi


#!/usr/bin/env python3
r"""
Generic Version Bump Script for GitHub Releases

Rules:
- If no existing tags for this report, create <report>-v1.0.0
- Compare latest tag to HEAD for changes in <report_dir>/<report_name>_report.tex
  - If any added lines contain "\section{", bump minor (X.Y+1.0)
  - Else if any added lines contain "\subsection{" or any other added lines, bump patch (X.Y.Z+1)
  - If no relevant changes to the file(s), print an empty string (no release)

Outputs the new tag (e.g. interim-v1.0.1) to stdout when a release is needed, or empty output when none.

Usage: python3 version_bump.py <report_name>
Example: python3 version_bump.py interim
Example: python3 version_bump.py final
"""
import subprocess
import sys
import re

if len(sys.argv) < 2:
    print("Usage: python3 version_bump.py <report_name>", file=sys.stderr)
    sys.exit(1)

REPORT_NAME = sys.argv[1]
FILEPATH = f'{REPORT_NAME}'


def run(cmd):
    return subprocess.check_output(cmd, shell=True, text=True).strip()


latest_tag = ''
try:
    tags = run(f"git tag --list '{REPORT_NAME}-v*' --sort=-v:refname")
    if tags:
        latest_tag = tags.splitlines()[0].strip()
except subprocess.CalledProcessError:
    latest_tag = ''

if not latest_tag:
    print(f"{REPORT_NAME}-v1.0.0")
    sys.exit(0)

m = re.match(rf"{re.escape(REPORT_NAME)}-v?(\d+)\.(\d+)\.(\d+)", str(latest_tag))
if not m:
    base_major, base_minor, base_patch = 1, 0, 0
else:
    base_major, base_minor, base_patch = map(int, m.groups())

try:
    diff = str(run(f"git diff --unified=0 {latest_tag} HEAD -- {FILEPATH}"))
except subprocess.CalledProcessError:
    print('')
    sys.exit(0)

if not diff:
    print('')
    sys.exit(0)

added_lines = [str(l[1:]) for l in diff.splitlines() if l.startswith('+') and not l.startswith('+++')]

if not added_lines:
    print('')
    sys.exit(0)

section_added = any(re.search(r"\\section\s*\{", str(l)) for l in added_lines)
subsection_added = any(re.search(r"\\subsection\s*\{", str(l)) for l in added_lines)

if section_added:
    new_tag = f"{REPORT_NAME}-v{base_major}.{base_minor + 1}.0"
    print(new_tag)
    sys.exit(0)

if subsection_added or any(True for _ in added_lines):
    new_tag = f"{REPORT_NAME}-v{base_major}.{base_minor}.{base_patch + 1}"
    print(new_tag)
    sys.exit(0)

print('')
sys.exit(0)

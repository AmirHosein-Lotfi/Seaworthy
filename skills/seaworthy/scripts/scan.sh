#!/usr/bin/env bash
# Seaworthy scanner orchestrator. Runs every detector in detectors/ against the
# given repo root and prints their combined JSONL output to stdout — one
# finding per line, nothing printed when a check finds nothing.
#
# Makes no network calls and never modifies the scanned repo. Findings are
# data, not failures: this script exits 0 whether or not issues were found.
# Non-zero exit means the scan itself broke (bad repo path, missing git), not
# that a security issue exists — SKILL.md is what turns findings into a
# verdict, not this script's exit code.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${1:?usage: scan.sh <repo_root>}"

if [ ! -d "$REPO_ROOT" ]; then
  echo "seaworthy: '$REPO_ROOT' is not a directory" >&2
  exit 1
fi
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"

for detector in "$SCRIPT_DIR"/detectors/*.sh; do
  [ -f "$detector" ] || continue
  bash "$detector" "$REPO_ROOT" 2>/dev/null
done

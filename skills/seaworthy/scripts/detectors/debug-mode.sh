#!/usr/bin/env bash
# check_id: debug-mode-enabled-prod (high)
# Hardcoded debug flags, not ones driven by an environment variable. See
# reference/checks-catalog.md and reference/django-flask.md.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="${1:?usage: debug-mode.sh <repo_root>}"

PATTERN='DEBUG[[:space:]]*=[[:space:]]*True|debug:[[:space:]]*true|app\.run\([^)]*debug[[:space:]]*=[[:space:]]*True|app\.debug[[:space:]]*=[[:space:]]*True'

search_repo "$REPO_ROOT" "$PATTERN" | while IFS= read -r line; do
  file="$(printf '%s' "$line" | cut -d: -f1)"
  lineno="$(printf '%s' "$line" | cut -d: -f2)"
  content="$(printf '%s' "$line" | cut -d: -f3-)"

  # If the same line also reads from an env var, this is the safe
  # environment-gated pattern, not a hardcoded flag.
  case "$content" in
    *os.environ*|*process.env*|*getenv*) continue ;;
  esac

  emit "debug-mode-enabled-prod" "high" "$file" "$lineno" "generic" "$content" "high"
done

#!/usr/bin/env bash
# check_id: secrets-hardcoded (critical)
# Looks for a real-looking literal secret assigned to a key/secret/password/
# token-named variable. process.env.X / os.environ[...] style access is the
# safe pattern and is excluded by the regex itself (it requires a quoted
# literal, not a property access). See reference/checks-catalog.md.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="${1:?usage: secrets.sh <repo_root>}"

PATTERN='(api[_-]?key|secret|password|token|access[_-]?key)[[:space:]]*[:=][[:space:]]*["\x27][A-Za-z0-9_./+-]{12,}["\x27]'

search_repo "$REPO_ROOT" "$PATTERN" | while IFS= read -r line; do
  file="$(printf '%s' "$line" | cut -d: -f1)"
  lineno="$(printf '%s' "$line" | cut -d: -f2)"
  content="$(printf '%s' "$line" | cut -d: -f3-)"

  # Pull just the quoted value out of the match to check against the
  # placeholder allowlist (a real check must look at the value, not the key
  # name — "apiKey = 'your-key-here'" is noise, not a finding).
  value="$(printf '%s' "$content" | grep -oE "[\"'][A-Za-z0-9_./+-]{12,}[\"']" | head -1 | tr -d "\"'")"
  if [ -n "$value" ] && is_placeholder_value "$value"; then
    continue
  fi
  # The safe pattern (env var access) won't match the literal-value regex
  # above at all, but guard anyway in case a line has both an env read and an
  # unrelated literal elsewhere on the same line.
  case "$content" in
    *process.env.*|*import.meta.env.*|*os.environ*) continue ;;
  esac

  emit "secrets-hardcoded" "critical" "$file" "$lineno" "generic" "$content" "high"
done

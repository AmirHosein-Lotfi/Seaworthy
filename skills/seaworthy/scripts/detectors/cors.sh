#!/usr/bin/env bash
# check_id: cors-wildcard-with-credentials (high)
# Wildcard origin alone is frequently intentional for a public API — only the
# combination with a credentials flag is the finding. See
# reference/checks-catalog.md and reference/node-express.md.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="${1:?usage: cors.sh <repo_root>}"

WILDCARD_PATTERN="Access-Control-Allow-Origin['\"]?[[:space:]]*[:,][[:space:]]*['\"]\\*['\"]|origin:[[:space:]]*['\"]\\*['\"]"
CREDENTIALS_PATTERN="Access-Control-Allow-Credentials['\"]?[[:space:]]*[:,][[:space:]]*['\"]?true|credentials:[[:space:]]*true|credentials:[[:space:]]*['\"]include['\"]"

search_repo "$REPO_ROOT" "$WILDCARD_PATTERN" | while IFS= read -r line; do
  file="$(printf '%s' "$line" | cut -d: -f1)"
  lineno="$(printf '%s' "$line" | cut -d: -f2)"
  content="$(printf '%s' "$line" | cut -d: -f3-)"

  full_path="$REPO_ROOT/$file"
  if grep -qE "$CREDENTIALS_PATTERN" "$full_path" 2>/dev/null; then
    emit "cors-wildcard-with-credentials" "high" "$file" "$lineno" "generic" "$content" "high"
  fi
done

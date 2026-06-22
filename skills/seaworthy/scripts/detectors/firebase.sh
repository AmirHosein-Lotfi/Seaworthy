#!/usr/bin/env bash
# check_id: firebase-rules-open (critical, experimental)
# Status: experimental — see reference/firebase.md. A missing rules file is
# explicitly NOT treated as a finding here, since that depends on project
# creation mode and static analysis can't tell; only an explicit "allow ...: if
# true" is flagged, always at reduced confidence.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="${1:?usage: firebase.sh <repo_root>}"

for rules_file in "firestore.rules" "storage.rules"; do
  full_path="$REPO_ROOT/$rules_file"
  [ -f "$full_path" ] || continue

  grep -nE 'allow[[:space:]]+(read|write|read,[[:space:]]*write)[[:space:]]*:[[:space:]]*if[[:space:]]+true' "$full_path" 2>/dev/null \
    | while IFS=: read -r lineno content; do
        emit "firebase-rules-open" "critical" "$rules_file" "$lineno" "firebase" "$content" "medium"
      done
done

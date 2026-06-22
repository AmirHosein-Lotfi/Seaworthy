#!/usr/bin/env bash
# check_id: admin-route-unprotected (high)
# Path-based heuristic: a route whose path looks administrative/internal with
# no recognized auth signal anywhere in its file. See reference/checks-catalog.md.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="${1:?usage: admin-routes.sh <repo_root>}"

PATH_PATTERN='(api|pages|routes)/(admin|internal|debug)[/.]'

# This is a path check, not a content check — list files and match the
# pattern against each path directly rather than piping into search_repo
# (which greps file *contents* and would never see a path string).
candidate_files="$(list_repo_files "$REPO_ROOT" | grep -iE "$PATH_PATTERN")"
[ -z "$candidate_files" ] && exit 0

printf '%s\n' "$candidate_files" | while IFS= read -r file; do
  [ -z "$file" ] && continue
  full_path="$REPO_ROOT/$file"
  [ -f "$full_path" ] || continue

  if has_positive_auth_signal "$full_path"; then
    continue
  fi

  emit "admin-route-unprotected" "high" "$file" "0" "generic" \
    "route path looks administrative/internal with no recognized auth check in this file" "medium"
done

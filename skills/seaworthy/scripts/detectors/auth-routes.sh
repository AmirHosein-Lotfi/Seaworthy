#!/usr/bin/env bash
# check_id: auth-route-missing-check (critical)
# A route file that performs a database write/mutation with no positive auth
# signal anywhere in the file, and that isn't a webhook (signature-verified)
# or a known public-by-design route (health checks, og images, cron). See
# reference/nextjs-supabase.md#auth-routes and reference/node-express.md#auth-routes
# for the framework-specific signal lists this relies on (loaded from
# allowlist.json so they stay in sync with the false-positive-rules doc).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="${1:?usage: auth-routes.sh <repo_root>}"

# Mutation-shaped calls: ORM/query-builder writes or raw SQL. Looking for the
# *presence* of a write is reliable; the harder, lower-confidence part is
# confirming the *absence* of an auth check, handled per-file below.
MUTATION_PATTERN='\.(insert|update|upsert|delete|destroy|save|create)\(|findOneAndUpdate\(|deleteOne\(|INSERT INTO|UPDATE [a-zA-Z_]+ SET|DELETE FROM'

# Only look inside files that are plausibly route/API handlers, to avoid
# flagging e.g. a one-off data migration script that legitimately has no auth
# concept.
ROUTE_PATH_PATTERN='(/api/|/routes/|/views\.py$|/server/)'

candidate_files="$(search_repo "$REPO_ROOT" "$MUTATION_PATTERN" | cut -d: -f1 | sort -u)"
[ -z "$candidate_files" ] && exit 0

printf '%s\n' "$candidate_files" | while IFS= read -r file; do
  [ -z "$file" ] && continue
  case "$file" in
    *api*|*routes*|*views.py|*server*) ;;
    *) continue ;;
  esac

  full_path="$REPO_ROOT/$file"
  [ -f "$full_path" ] || continue

  if is_public_route_path "$file"; then
    continue
  fi
  if has_webhook_signature_signal "$full_path"; then
    continue
  fi
  if has_positive_auth_signal "$full_path"; then
    continue
  fi

  # No positive signal found anywhere in the file. Report at medium confidence
  # rather than asserting certainty — a custom/unrecognized auth wrapper would
  # also produce this result, and reference/false-positive-rules.md is explicit
  # that an unrecognized pattern is a missed signal, not a confirmed bug.
  first_match_line="$(grep -nE "$MUTATION_PATTERN" "$full_path" 2>/dev/null | head -1 | cut -d: -f1)"
  [ -z "$first_match_line" ] && first_match_line=0
  emit "auth-route-missing-check" "critical" "$file" "$first_match_line" "generic" \
    "database write found with no recognized auth check in this file" "medium"
done

#!/usr/bin/env bash
# check_ids: supabase-anon-key-without-confirmed-rls (critical),
#            supabase-service-role-key-client-exposed (critical),
#            supabase-rls-partial-coverage (medium)
# See reference/nextjs-supabase.md#rls for the full reasoning this implements:
# RLS can be enabled in a *different* migration file than the one that created
# the table, so we collect table names across the whole migrations directory
# before comparing — a naive per-file check would miss that and false-positive
# constantly.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="${1:?usage: supabase.sh <repo_root>}"

# Gate: only run Supabase-specific checks on projects that actually use
# Supabase. Without this, every other stack would pay the cost of these greps
# for nothing.
if ! search_repo "$REPO_ROOT" '@supabase/supabase-js|createClient\(' >/dev/null 2>&1; then
  exit 0
fi
HAS_SUPABASE="$(search_repo "$REPO_ROOT" '@supabase/supabase-js' | head -1)"
[ -z "$HAS_SUPABASE" ] && exit 0

### 1. service_role key exposed in what looks like client-side code
search_repo "$REPO_ROOT" 'service_role' | while IFS= read -r line; do
  file="$(printf '%s' "$line" | cut -d: -f1)"
  lineno="$(printf '%s' "$line" | cut -d: -f2)"
  content="$(printf '%s' "$line" | cut -d: -f3-)"

  is_server=0
  case "$file" in
    *api/*|*server*|*/server/*) is_server=1 ;;
  esac
  if [ "$is_server" -eq 0 ] && grep -qF "'use server'" "$REPO_ROOT/$file" 2>/dev/null; then
    is_server=1
  fi
  if [ "$is_server" -eq 0 ]; then
    emit "supabase-service-role-key-client-exposed" "critical" "$file" "$lineno" "supabase" "$content" "high"
  fi
done

### 2. RLS coverage across all migration files
MIGRATIONS_DIR="$REPO_ROOT/supabase/migrations"
if [ ! -d "$MIGRATIONS_DIR" ]; then
  emit "supabase-anon-key-without-confirmed-rls" "critical" "supabase/migrations" "0" "supabase" \
    "no migrations directory found - RLS status cannot be confirmed from code" "low"
  exit 0
fi

CREATED_TABLES="$(grep -ohiE "create table( if not exists)?[[:space:]]+[\"\`]?(public\.)?[a-zA-Z0-9_]+" "$MIGRATIONS_DIR"/*.sql 2>/dev/null \
  | grep -oiE '[a-zA-Z0-9_]+$' | tr '[:upper:]' '[:lower:]' | sort -u)"
RLS_TABLES="$(grep -ohiE "alter table( if exists)?[[:space:]]+[\"\`]?(public\.)?[a-zA-Z0-9_]+[\"\`]?[[:space:]]+enable row level security" "$MIGRATIONS_DIR"/*.sql 2>/dev/null \
  | grep -oiE '[a-zA-Z0-9_]+[[:space:]]+enable' | awk '{print $1}' | tr '[:upper:]' '[:lower:]' | sort -u)"

[ -z "$CREATED_TABLES" ] && exit 0

MISSING_TABLES="$(comm -23 <(printf '%s\n' "$CREATED_TABLES") <(printf '%s\n' "$RLS_TABLES") 2>/dev/null)"
[ -z "$MISSING_TABLES" ] && exit 0

RLS_USED_ANYWHERE=0
[ -n "$RLS_TABLES" ] && RLS_USED_ANYWHERE=1

printf '%s\n' "$MISSING_TABLES" | while IFS= read -r table; do
  [ -z "$table" ] && continue

  reachable="medium"
  if search_repo "$REPO_ROOT" "\.from\(['\"]${table}['\"]\)" | head -1 | grep -q .; then
    reachable="high"
  fi

  if [ "$RLS_USED_ANYWHERE" -eq 1 ]; then
    emit "supabase-rls-partial-coverage" "medium" "supabase/migrations" "0" "supabase" \
      "table '$table' has no RLS enable statement while other tables do" "$reachable"
  else
    emit "supabase-anon-key-without-confirmed-rls" "critical" "supabase/migrations" "0" "supabase" \
      "table '$table' created with no RLS enable statement found in any migration" "$reachable"
  fi
done

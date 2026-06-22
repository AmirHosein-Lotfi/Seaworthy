#!/usr/bin/env bash
# Regression test for the detector scripts (the deterministic layer only —
# this does NOT test SKILL.md's prose rendering, see tests/README or the repo
# README for the separate Claude-level verification step).
#
# For each fixture, runs scan.sh and asserts the expected check_ids are present
# (vuln-* fixtures) or absent (clean-* fixtures). Exits non-zero if any
# assertion fails, so this can be wired into CI later.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN_SH="$SCRIPT_DIR/../skills/seaworthy/scripts/scan.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

PASS=0
FAIL=0

# Fixtures need to be real git repos for the git-history/.gitignore checks to
# mean anything, but their .git/ dirs are gitignored in *this* repo (to avoid
# committing them as broken nested-repo gitlinks — see ../.gitignore). So a
# fresh clone won't have them yet: initialize and commit each fixture here if
# it isn't already a repo, idempotently.
for fixture_dir in "$FIXTURES_DIR"/*/; do
  if [ ! -d "$fixture_dir/.git" ]; then
    ( cd "$fixture_dir" \
      && git init -q \
      && git add -A \
      && git -c user.email=fixture@seaworthy.local -c user.name=seaworthy-fixtures commit -q -m "init fixture" )
  fi
done

assert_present() {
  local fixture="$1" check_id="$2" findings="$3"
  if printf '%s' "$findings" | grep -q "\"check_id\":\"$check_id\""; then
    echo "  PASS: $check_id found in $fixture"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $check_id NOT found in $fixture (expected it to be)"
    FAIL=$((FAIL + 1))
  fi
}

assert_absent() {
  local fixture="$1" check_id="$2" findings="$3"
  if printf '%s' "$findings" | grep -q "\"check_id\":\"$check_id\""; then
    echo "  FAIL: $check_id found in $fixture (expected zero findings here)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $check_id absent from $fixture"
    PASS=$((PASS + 1))
  fi
}

echo "=== vuln-moltbook-pattern ==="
FINDINGS="$(bash "$SCAN_SH" "$FIXTURES_DIR/vuln-moltbook-pattern" 2>/dev/null)"
assert_present "vuln-moltbook-pattern" "supabase-anon-key-without-confirmed-rls" "$FINDINGS"

echo "=== vuln-lovable-pattern ==="
FINDINGS="$(bash "$SCAN_SH" "$FIXTURES_DIR/vuln-lovable-pattern" 2>/dev/null)"
assert_present "vuln-lovable-pattern" "auth-route-missing-check" "$FINDINGS"

echo "=== vuln-kitchen-sink ==="
FINDINGS="$(bash "$SCAN_SH" "$FIXTURES_DIR/vuln-kitchen-sink" 2>/dev/null)"
assert_present "vuln-kitchen-sink" "secrets-hardcoded" "$FINDINGS"
assert_present "vuln-kitchen-sink" "env-file-in-git-history" "$FINDINGS"
assert_present "vuln-kitchen-sink" "env-missing-from-gitignore" "$FINDINGS"
assert_present "vuln-kitchen-sink" "cors-wildcard-with-credentials" "$FINDINGS"
assert_present "vuln-kitchen-sink" "debug-mode-enabled-prod" "$FINDINGS"
assert_present "vuln-kitchen-sink" "admin-route-unprotected" "$FINDINGS"
assert_present "vuln-kitchen-sink" "cloud-storage-public-write" "$FINDINGS"

echo "=== clean-nextjs-supabase (false-positive guard) ==="
FINDINGS="$(bash "$SCAN_SH" "$FIXTURES_DIR/clean-nextjs-supabase" 2>/dev/null)"
assert_absent "clean-nextjs-supabase" "supabase-anon-key-without-confirmed-rls" "$FINDINGS"
assert_absent "clean-nextjs-supabase" "supabase-service-role-key-client-exposed" "$FINDINGS"
assert_absent "clean-nextjs-supabase" "auth-route-missing-check" "$FINDINGS"
assert_absent "clean-nextjs-supabase" "secrets-hardcoded" "$FINDINGS"
assert_absent "clean-nextjs-supabase" "env-file-in-git-history" "$FINDINGS"
assert_absent "clean-nextjs-supabase" "env-missing-from-gitignore" "$FINDINGS"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]

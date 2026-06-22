#!/usr/bin/env bash
# Shared helpers for seaworthy detectors. Sourced by scan.sh and each detector
# script — see ../../reference/false-positive-rules.md for what each guard is
# protecting against; this file only implements the mechanics, not the policy.

SEAWORTHY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEAWORTHY_ALLOWLIST="$SEAWORTHY_LIB_DIR/allowlist.json"

# Emit one JSONL finding to stdout. Callers build the JSON object string
# themselves (keeps this file free of JSON-construction logic) — this just
# centralizes the "always one line, always stdout, never a file" contract.
emit_finding() {
  printf '%s\n' "$1"
}

# Escape a string for safe embedding inside a JSON string value (backslash,
# double-quote, and control characters). Every detector should pass file
# snippets/paths through this before interpolating them into a finding line —
# unescaped quotes or newlines in matched source code would otherwise break the
# JSONL contract that scan.sh and SKILL.md both rely on.
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  printf '%s' "$s"
}

# Build one JSONL finding line from named fields and emit it. Keeps the JSON
# shape (check_id, severity, file, line, stack, matched, confidence) identical
# across every detector instead of each one hand-rolling printf statements.
emit() {
  local check_id="$1" severity="$2" file="$3" line="$4" stack="$5" matched="$6" confidence="${7:-high}"
  emit_finding "{\"check_id\":\"$(json_escape "$check_id")\",\"severity\":\"$(json_escape "$severity")\",\"file\":\"$(json_escape "$file")\",\"line\":$line,\"stack\":\"$(json_escape "$stack")\",\"matched\":\"$(json_escape "$matched")\",\"confidence\":\"$(json_escape "$confidence")\"}"
}

# Extract a JSON array of strings for the given top-level key from allowlist.json,
# one value per line. Uses jq if available; otherwise falls back to a line-based
# parser that works because allowlist.json is hand-formatted with one array
# element per line — this keeps the scanner dependency-free on systems without jq.
allowlist_array() {
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r ".${key}[]" "$SEAWORTHY_ALLOWLIST"
  else
    awk -v key="\"${key}\"" '
      index($0, key) { in_array=1; next }
      in_array && /\]/ { in_array=0; next }
      in_array {
        line=$0
        gsub(/^[ \t]*"/, "", line)
        gsub(/",?[ \t]*$/, "", line)
        if (length(line) > 0) print line
      }
    ' "$SEAWORTHY_ALLOWLIST"
  fi
}

# True (exit 0) if the given path matches any glob in path_skip_globs (tests,
# fixtures, vendor, docs, build output...). Used as a second filter after
# search_repo, since not every noisy path is guaranteed to be gitignored.
path_is_allowlisted() {
  local path="$1" glob
  while IFS= read -r glob; do
    case "$path" in
      $glob) return 0 ;;
    esac
  done < <(allowlist_array path_skip_globs)
  return 1
}

# Search the repo for an extended-regex pattern and print results as
# "file:line:content", one per line — the single entry point every detector
# uses instead of calling grep/rg directly, so there's one place that decides
# how to walk the repo.
#
# Prefers `git grep` (ships with git, which every target repo already has by
# definition — these checks are about what's about to be pushed/deployed) since
# it transparently skips .gitignore'd paths like node_modules and dist without
# any exclude list, and is fast even on large repos. Falls back to a plain
# `find` + `grep` walk for repos that aren't (yet) a git repository, with a
# small hardcoded exclude list since .gitignore can't help there.
#
# Deliberately does NOT depend on ripgrep — it's a common dev tool but not a
# safe assumption for a security check meant to run on anyone's machine with
# nothing more than git installed.
search_repo() {
  local repo_root="$1" pattern="$2"
  local result
  if git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    result="$(git -C "$repo_root" grep -n -i -I -E --untracked -e "$pattern" -- . 2>/dev/null || true)"
  else
    result="$(find "$repo_root" \
      \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/dist/*' \
         -o -path '*/.next/*' -o -path '*/build/*' -o -path '*/vendor/*' \) -prune -o \
      -type f -print 2>/dev/null \
      | xargs -I{} grep -n -H -i -I -E "$pattern" {} 2>/dev/null || true)"
  fi
  [ -z "$result" ] && return 0
  printf '%s\n' "$result" | while IFS= read -r line; do
    local abs_path="${line%%:*}"
    local rest="${line#*:}"
    local rel_path="${abs_path#"$repo_root"/}"
    rel_path="${rel_path#"$repo_root"\\}"
    if ! path_is_allowlisted "$rel_path"; then
      printf '%s:%s\n' "$rel_path" "$rest"
    fi
  done
}

# List every file in the repo (relative paths, one per line), respecting the
# same git-tracked-or-find-fallback logic and path allowlist as search_repo —
# but without a content grep. Use this for checks that care about a file's
# *path* (e.g. "is this route under /admin/") rather than its contents;
# piping a path pattern into search_repo (which greps file contents) silently
# matches nothing, since the path string isn't part of any file's content.
list_repo_files() {
  local repo_root="$1"
  local result
  if git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    result="$(git -C "$repo_root" ls-files --cached --others --exclude-standard 2>/dev/null || true)"
  else
    result="$(find "$repo_root" \
      \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/dist/*' \
         -o -path '*/.next/*' -o -path '*/build/*' -o -path '*/vendor/*' \) -prune -o \
      -type f -print 2>/dev/null \
      | while IFS= read -r f; do printf '%s\n' "${f#"$repo_root"/}"; done || true)"
  fi
  [ -z "$result" ] && return 0
  printf '%s\n' "$result" | while IFS= read -r rel_path; do
    path_is_allowlisted "$rel_path" || printf '%s\n' "$rel_path"
  done
}

# True (exit 0) if the given file is covered by .gitignore in the given repo root.
is_gitignored() {
  local repo_root="$1" file="$2"
  git -C "$repo_root" check-ignore -q "$file" 2>/dev/null
}

# True (exit 0) if the given file path pattern was ever added in git history,
# even if it was later deleted or gitignored. This is the check that catches a
# secret that's "clean now" but still sitting in an old commit.
was_ever_committed() {
  local repo_root="$1" file_pattern="$2"
  git -C "$repo_root" log --all --diff-filter=A --name-only --pretty=format: 2>/dev/null \
    | grep -Eq "$file_pattern"
}

# True (exit 0) if the given string is a known placeholder (case-insensitive),
# meaning a "hardcoded secret" match against it is noise, not a real finding.
is_placeholder_value() {
  local value_lower placeholder
  value_lower="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  while IFS= read -r placeholder; do
    [ "$value_lower" = "$placeholder" ] && return 0
  done < <(allowlist_array secret_placeholder_values)
  return 1
}

# True (exit 0) if any known auth-positive signal string appears in the file.
# This is intentionally a simple substring search, not a full parser — the goal
# is to catch the common, real auth patterns documented in
# reference/nextjs-supabase.md and reference/node-express.md, not to be a
# static analyzer. False negatives here (an unrecognized custom auth wrapper)
# should be treated as low-confidence findings by the caller, not asserted bugs.
has_positive_auth_signal() {
  local file="$1" signal
  while IFS= read -r signal; do
    grep -qF -- "$signal" "$file" 2>/dev/null && return 0
  done < <(allowlist_array auth_positive_signals)
  return 1
}

# True (exit 0) if the file looks like it verifies a webhook signature rather
# than a user session — these routes are expected to have no session check.
has_webhook_signature_signal() {
  local file="$1" signal
  while IFS= read -r signal; do
    grep -qF -- "$signal" "$file" 2>/dev/null && return 0
  done < <(allowlist_array webhook_signature_signals)
  return 1
}

# True (exit 0) if the route path matches a known public-by-design pattern
# (health checks, og-image generation, webhooks, cron).
is_public_route_path() {
  local path="$1" pattern
  while IFS= read -r pattern; do
    case "$path" in
      *"$pattern"*) return 0 ;;
    esac
  done < <(allowlist_array public_route_name_allowlist)
  return 1
}

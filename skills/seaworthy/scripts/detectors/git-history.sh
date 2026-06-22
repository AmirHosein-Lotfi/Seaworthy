#!/usr/bin/env bash
# check_id: env-file-in-git-history (high), env-missing-from-gitignore (medium)
# .env.example / .env.sample are intentionally excluded everywhere here — those
# files are meant to be committed and shouldn't contain real values, but their
# existence isn't what these two checks are for. See reference/checks-catalog.md.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="${1:?usage: git-history.sh <repo_root>}"
ENV_NAMES=(".env" ".env.local" ".env.development" ".env.production" ".env.staging")

if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # No git repo at all — can't check history or .gitignore coverage. Both
  # checks are meaningless without git, so skip silently rather than emit a
  # confusing finding about a feature that doesn't apply.
  exit 0
fi

for name in "${ENV_NAMES[@]}"; do
  # env-file-in-git-history: was this exact filename ever added in any commit,
  # on any branch, even if it's since been deleted or gitignored?
  pattern="(^|/)${name//./\\.}\$"
  if was_ever_committed "$REPO_ROOT" "$pattern"; then
    emit "env-file-in-git-history" "high" "$name" "0" "generic" "found in git history" "high"
  fi

  # env-missing-from-gitignore: does it exist on disk right now, uncommitted
  # is fine, but only safe if .gitignore actually covers it.
  if [ -f "$REPO_ROOT/$name" ] && ! is_gitignored "$REPO_ROOT" "$name"; then
    emit "env-missing-from-gitignore" "medium" "$name" "0" "generic" "exists, not gitignored" "high"
  fi
done

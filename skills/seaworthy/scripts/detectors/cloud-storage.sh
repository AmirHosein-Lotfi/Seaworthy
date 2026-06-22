#!/usr/bin/env bash
# check_id: cloud-storage-public-write (critical)
# Static IaC/config checks only — deliberately no live cloud API calls, to
# keep the whole scan network-free. See reference/checks-catalog.md.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="${1:?usage: cloud-storage.sh <repo_root>}"

# Covers both JSON ("Principal": "*") and HCL/Terraform (Principal = "*")
# styles, since IaC for the same disaster pattern shows up in either syntax.
PATTERN='allUsers|public-read-write|"?Principal"?[[:space:]]*[:=][[:space:]]*"\*"|AllUsers.*WRITE'

search_repo "$REPO_ROOT" "$PATTERN" | while IFS= read -r line; do
  file="$(printf '%s' "$line" | cut -d: -f1)"
  lineno="$(printf '%s' "$line" | cut -d: -f2)"
  content="$(printf '%s' "$line" | cut -d: -f3-)"

  case "$file" in
    *.tf|*.yml|*.yaml|*config*) ;;
    *) continue ;;
  esac

  emit "cloud-storage-public-write" "critical" "$file" "$lineno" "generic" "$content" "medium"
done

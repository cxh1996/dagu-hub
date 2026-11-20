#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ensure_dirs

SUMMARY="PR touches $(wc -l <"${ARTIFACTS_DIR}/review_files.txt" | tr -d ' ') reviewable files"
printf '%s\n' "$SUMMARY" >"${ARTIFACTS_DIR}/diff_summary.txt"
log "$SUMMARY"
emit diff_summary "$SUMMARY"

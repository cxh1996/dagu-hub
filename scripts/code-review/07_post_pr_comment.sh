#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ensure_dirs

REPO="${repo:-${REPO:-unknown}}"
PR_NUMBER="${pr_number:-${PR_NUMBER:-0}}"
REPORT="${ARTIFACTS_DIR}/report.md"

# 生产：gh pr comment / GitHub API
COMMENT_URL="https://github.com/${REPO}/pull/${PR_NUMBER}#dagu-${DAG_RUN_ID}"
printf '%s\n' "$COMMENT_URL" >"${ARTIFACTS_DIR}/comment_url.txt"
log "posted comment (simulated): $COMMENT_URL"
[[ -f "$REPORT" ]] && log "report bytes=$(wc -c <"$REPORT")"
emit comment_url "$COMMENT_URL"

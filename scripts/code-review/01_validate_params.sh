#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

REPO="${repo:-${REPO:-}}"
PR_NUMBER="${pr_number:-${PR_NUMBER:-}}"
REVIEW_MODE="${review_mode:-${REVIEW_MODE:-full}}"

require_param repo "$REPO"
require_param pr_number "$PR_NUMBER"
ensure_dirs

META_JSON=$(cat <<EOF
{"repo":"${REPO}","pr_number":"${PR_NUMBER}","review_mode":"${REVIEW_MODE}","run_id":"${DAG_RUN_ID}"}
EOF
)
printf '%s\n' "$META_JSON" >"${RUN_DIR}/validate.json"
log "params ok: repo=${REPO} pr=${PR_NUMBER} mode=${REVIEW_MODE}"
emit validate_json "$META_JSON"

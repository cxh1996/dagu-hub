#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ensure_dirs

STATUS="unknown"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --status) STATUS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# 业务记录只写 Worker 本地库（示例：JSONL；可换成 SQLite）
RECORD_DB="${WORKER_DATA_DIR}/code_review_runs.jsonl"
RECORD=$(cat <<EOF
{"ts":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","run_id":"${DAG_RUN_ID}","status":"${STATUS}","repo":"${repo:-}","pr_number":"${pr_number:-}","record_dir":"${RUN_DIR}"}
EOF
)
printf '%s\n' "$RECORD" >>"$RECORD_DB"
log "persisted run status=${STATUS} -> ${RECORD_DB}"

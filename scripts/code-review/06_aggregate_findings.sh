#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ensure_dirs

# 汇聚 Worker 本地 findings 目录（多输入在上一步 depends 已对齐）
AGG="${ARTIFACTS_DIR}/aggregate.json"
{
  echo '{'
  echo '  "run_id": "'"${DAG_RUN_ID}"'",'
  echo '  "findings_dir": "'"${FINDINGS_DIR}"'",'
  echo '  "files": ['
  first=1
  for f in "${FINDINGS_DIR}"/*.json; do
    [[ -f "$f" ]] || continue
    if [[ $first -eq 0 ]]; then echo ','; fi
    first=0
    cat "$f"
  done
  echo '  ]'
  echo '}'
} >"$AGG"

log "aggregated findings -> $AGG"
emit aggregate_json "$(cat "$AGG")"

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ensure_dirs

REPO="${repo:-${REPO:-unknown}}"
PR_NUMBER="${pr_number:-${PR_NUMBER:-0}}"
SCORE=$(cat "${ARTIFACTS_DIR}/risk_score.txt" 2>/dev/null || echo 0)
REPORT="${ARTIFACTS_DIR}/report.md"

cat >"$REPORT" <<EOF
# Code Review Report

- **Repo**: ${REPO}
- **PR**: #${PR_NUMBER}
- **Run**: ${DAG_RUN_ID}
- **Risk score**: ${SCORE}

## Findings

见 Worker 本地目录 \`${FINDINGS_DIR}\`（业务数据隔离，不写主 Dagu 磁盘）。

EOF

log "report rendered: $REPORT"
emit report_path "$REPORT"

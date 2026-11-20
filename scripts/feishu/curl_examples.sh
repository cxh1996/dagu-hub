#!/usr/bin/env bash
# 主 Dagu API 调用示例（飞书 / Agent / CI 可直接复用）
set -euo pipefail

DAGU_BASE_URL="${DAGU_BASE_URL:-http://127.0.0.1:8080}"
TOKEN_HEADER=()
if [[ -n "${DAGU_API_TOKEN:-}" ]]; then
  TOKEN_HEADER=(-H "Authorization: Bearer ${DAGU_API_TOKEN}")
fi

REPO="${1:-org/demo-app}"
PR="${2:-101}"
RUN_ID="cr-${REPO//\//-}-pr${PR}-$(date +%s)"

PARAMS=$(cat <<EOF
{"repo":"${REPO}","pr_number":"${PR}","base_branch":"main","head_sha":"","review_mode":"full","enable_security":"true","notify_feishu":"true","feishu_chat_id":""}
EOF
)

echo "==> start code-review run_id=${RUN_ID}"
curl -fsS -X POST "${DAGU_BASE_URL}/api/v1/dags/code-review/start" \
  "${TOKEN_HEADER[@]}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg p "$PARAMS" --arg id "$RUN_ID" '{params:$p, dagRunId:$id, singleton:false}')"

echo
echo "==> query status"
curl -fsS "${DAGU_BASE_URL}/api/v1/dags/code-review/dag-runs/${RUN_ID}" \
  "${TOKEN_HEADER[@]}" \
  -H "Accept: application/json"
echo

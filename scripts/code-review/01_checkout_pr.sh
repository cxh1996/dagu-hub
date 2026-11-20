#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ensure_dirs

REPO="${repo:-${REPO:-}}"
PR_NUMBER="${pr_number:-${PR_NUMBER:-}}"
BASE_BRANCH="${base_branch:-${BASE_BRANCH:-main}}"
HEAD_SHA="${head_sha:-${HEAD_SHA:-}}"

# 生产环境在此调用 gh / git；示例写入占位 checkout 元数据
META=$(cat <<EOF
{"repo":"${REPO}","pr":"${PR_NUMBER}","base":"${BASE_BRANCH}","head":"${HEAD_SHA:-unknown}","workspace":"${WORKSPACE_DIR}"}
EOF
)
printf '%s\n' "$META" >"${ARTIFACTS_DIR}/checkout.json"
# 模拟已 checkout 的树
mkdir -p "${WORKSPACE_DIR}/src"
printf 'placeholder for %s#%s\n' "$REPO" "$PR_NUMBER" >"${WORKSPACE_DIR}/README.checkout"

log "checkout simulated for ${REPO}#${PR_NUMBER}"
emit checkout_meta "$META"

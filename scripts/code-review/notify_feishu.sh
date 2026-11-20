#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ensure_dirs

EVENT="success"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --event) EVENT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

CHAT_ID="${feishu_chat_id:-${FEISHU_CHAT_ID:-}}"
WEBHOOK="${FEISHU_BOT_WEBHOOK:-}"

MSG_ID="feishu-sim-${DAG_RUN_ID}-${EVENT}"
PAYLOAD=$(cat <<EOF
{"event":"${EVENT}","run_id":"${DAG_RUN_ID}","chat_id":"${CHAT_ID}","repo":"${repo:-}","pr":"${pr_number:-}"}
EOF
)
printf '%s\n' "$PAYLOAD" >"${ARTIFACTS_DIR}/feishu_${EVENT}.json"

if [[ -n "$WEBHOOK" ]]; then
  curl -fsS -X POST "$WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{\"msg_type\":\"text\",\"content\":{\"text\":\"Code Review ${EVENT}: ${repo:-}#${pr_number:-} run=${DAG_RUN_ID}\"}}" \
    >/dev/null || log "feishu webhook call failed (non-fatal in demo)"
fi

log "feishu notify event=${EVENT} msg_id=${MSG_ID}"
emit feishu_msg_id "$MSG_ID"

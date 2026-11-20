#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ensure_dirs

# 演示 repeat_policy：前几次失败，随后成功
FLAG="${RUN_DIR}/.policy_attempts"
ATTEMPTS=0
if [[ -f "$FLAG" ]]; then
  ATTEMPTS=$(cat "$FLAG")
fi
ATTEMPTS=$((ATTEMPTS + 1))
echo "$ATTEMPTS" >"$FLAG"

if [[ "$ATTEMPTS" -lt 2 ]]; then
  log "policy not ready yet (attempt ${ATTEMPTS})"
  exit 1
fi

RESULT='{"policy":"ready","attempt":'"${ATTEMPTS}"'}'
printf '%s\n' "$RESULT" >"${ARTIFACTS_DIR}/policy_ready.json"
log "policy ready"
emit policy_ready "$RESULT"

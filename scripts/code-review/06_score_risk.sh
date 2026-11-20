#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ensure_dirs

# 简易评分：有 medium/high 则抬高
SCORE=10
if grep -q '"high":[1-9]' "${FINDINGS_DIR}"/*.json 2>/dev/null; then
  SCORE=80
elif grep -q '"medium":[1-9]' "${FINDINGS_DIR}"/*.json 2>/dev/null; then
  SCORE=40
fi

printf '%s\n' "$SCORE" >"${ARTIFACTS_DIR}/risk_score.txt"
log "risk score=${SCORE}"
emit risk_score "$SCORE"

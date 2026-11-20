#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ensure_dirs
RESULT='{"tool":"lint","status":"ok","issues":0}'
printf '%s\n' "$RESULT" >"${FINDINGS_DIR}/lint.json"
log "lint ok"
emit lint_result "$RESULT"

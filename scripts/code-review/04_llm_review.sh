#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ensure_dirs

FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done
FILE="${FILE:-${file:-}}"
require_param file "$FILE"

SAFE=$(printf '%s' "$FILE" | tr '/.' '__')
OUT="${FINDINGS_DIR}/llm_${SAFE}.json"
RESULT=$(cat <<EOF
{"file":"${FILE}","findings":[{"severity":"info","message":"Consider adding error handling"}]}
EOF
)
printf '%s\n' "$RESULT" >"$OUT"
log "llm review $FILE"
emit llm_findings "$RESULT"

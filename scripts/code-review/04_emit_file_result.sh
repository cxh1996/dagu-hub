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
RESULT=$(cat <<EOF
{"file":"${FILE}","status":"reviewed"}
EOF
)
printf '%s\n' "$RESULT" >"${FINDINGS_DIR}/file_${SAFE}.json"
log "emitted result for $FILE"
emit file_result "$RESULT"

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ensure_dirs

# 过滤 lockfile / 文档等，输出给 parallel.items 的换行列表
FILTERED="${ARTIFACTS_DIR}/review_files.txt"
: >"$FILTERED"
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    *.lock|package-lock.json|yarn.lock|pnpm-lock.yaml|docs/*|*.md)
      log "skip: $path"
      ;;
    *)
      printf '%s\n' "$path" >>"$FILTERED"
      ;;
  esac
done <"${ARTIFACTS_DIR}/changed_files.txt"

LIST=$(cat "$FILTERED")
log "review files:"$'\n'"$LIST"
emit file_list "$LIST"

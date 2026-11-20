#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ensure_dirs

# 示例：写入若干变更文件；生产用 gh pr diff / git diff
cat >"${ARTIFACTS_DIR}/changed_files.txt" <<'EOF'
src/api/handler.go
src/api/auth.go
web/components/ReviewPanel.tsx
docs/README.md
package-lock.json
EOF

COUNT=$(wc -l <"${ARTIFACTS_DIR}/changed_files.txt" | tr -d ' ')
META="{\"changed_files\":${COUNT}}"
printf '%s\n' "$META" >"${ARTIFACTS_DIR}/diff_meta.json"
log "collected ${COUNT} changed files"
emit diff_meta "$META"

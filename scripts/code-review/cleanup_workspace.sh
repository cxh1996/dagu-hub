#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

# 默认保留 artifacts；仅清理大体积 checkout（可按策略调整）
if [[ -d "${WORKSPACE_DIR}" ]]; then
  # 演示：不强制删除，只写标记
  date -u +%Y-%m-%dT%H:%M:%SZ >"${RUN_DIR}/cleaned_at"
  log "cleanup marker written (workspace kept for debug)"
fi

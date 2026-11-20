#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
ensure_dirs
log "workspace ready: ${WORKSPACE_DIR}"
emit workspace "$WORKSPACE_DIR"

#!/usr/bin/env bash
# 公共库：路径约定、JSON 小工具、输出写入
set -euo pipefail

: "${WORKER_DATA_DIR:=./data}"
: "${DAG_RUN_ID:=local-dev}"
: "${SCRIPTS_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

RUN_DIR="${WORKER_DATA_DIR}/runs/${DAG_RUN_ID}"
WORKSPACE_DIR="${RUN_DIR}/workspace"
ARTIFACTS_DIR="${RUN_DIR}/artifacts"
FINDINGS_DIR="${RUN_DIR}/findings"

ensure_dirs() {
  mkdir -p "$RUN_DIR" "$WORKSPACE_DIR" "$ARTIFACTS_DIR" "$FINDINGS_DIR"
}

# 向 Dagu 声明的 outputs 写 name=value（见官方 Outputs 文档）
emit() {
  local key="$1"
  local value="$2"
  if [[ -n "${DAGU_OUTPUT_FILE:-}" ]]; then
    # 多行值用 heredoc 风格；简单值直接写
    if [[ "$value" == *$'\n'* ]]; then
      {
        printf '%s<<DAGU_EOF\n' "$key"
        printf '%s\n' "$value"
        printf 'DAGU_EOF\n'
      } >>"$DAGU_OUTPUT_FILE"
    else
      printf '%s=%s\n' "$key" "$value" >>"$DAGU_OUTPUT_FILE"
    fi
  else
    echo "[emit] $key=$value" >&2
  fi
}

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$DAG_RUN_ID] $*"
}

require_param() {
  local name="$1"
  local value="${2:-}"
  if [[ -z "$value" ]]; then
    echo "missing required param: $name" >&2
    exit 2
  fi
}

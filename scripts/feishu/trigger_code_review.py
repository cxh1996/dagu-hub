#!/usr/bin/env python3
"""
飞书机器人 / 外部 Agent 通过主 Dagu REST API 触发 Code Review DAG。

用法：
  export DAGU_BASE_URL=http://127.0.0.1:8080
  export DAGU_API_TOKEN=dagu_xxx          # 开启 Builtin Auth 后需要
  python3 trigger_code_review.py --repo org/app --pr 42

飞书事件回调里调用 trigger_code_review(...) 即可。
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from typing import Any


def _headers(token: str | None) -> dict[str, str]:
    h = {"Content-Type": "application/json", "Accept": "application/json"}
    if token:
        h["Authorization"] = f"Bearer {token}"
    return h


def _request(
    method: str,
    url: str,
    *,
    token: str | None = None,
    body: dict[str, Any] | None = None,
    timeout: float = 30.0,
) -> dict[str, Any]:
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=_headers(token), method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code} {url}: {detail}") from e


def trigger_code_review(
    *,
    base_url: str,
    token: str | None,
    repo: str,
    pr_number: int | str,
    base_branch: str = "main",
    head_sha: str = "",
    review_mode: str = "full",
    enable_security: str = "true",
    notify_feishu: str = "true",
    feishu_chat_id: str = "",
    dag_file: str = "code-review",
) -> dict[str, Any]:
    """
    POST /api/v1/dags/{fileName}/start

    - 不设 singleton，允许多 PR 并发
    - 自定义 dagRunId，便于飞书侧跟踪
    - workerSelector 可在运行时覆盖（一般 DAG 内已声明）
    """
    base_url = base_url.rstrip("/")
    run_id = f"cr-{repo.replace('/', '-')}-pr{pr_number}-{int(time.time())}"

    params_obj = {
        "repo": repo,
        "pr_number": str(pr_number),
        "base_branch": base_branch,
        "head_sha": head_sha,
        "review_mode": review_mode,
        "enable_security": enable_security,
        "notify_feishu": notify_feishu,
        "feishu_chat_id": feishu_chat_id,
    }

    body = {
        # 官方 API：params 为 JSON 字符串
        "params": json.dumps(params_obj, ensure_ascii=False),
        "dagRunId": run_id,
        "singleton": False,
        # 可选：运行时强制路由（通常 DAG YAML 已写死 role=code-review）
        # "workerSelector": {"role": "code-review"},
    }

    url = f"{base_url}/api/v1/dags/{dag_file}/start"
    result = _request("POST", url, token=token, body=body)
    result.setdefault("dagRunId", run_id)
    return result


def get_run_status(
    *,
    base_url: str,
    token: str | None,
    dag_file: str,
    dag_run_id: str,
) -> dict[str, Any]:
    base_url = base_url.rstrip("/")
    url = f"{base_url}/api/v1/dags/{dag_file}/dag-runs/{dag_run_id}"
    return _request("GET", url, token=token)


def enqueue_code_review(**kwargs: Any) -> dict[str, Any]:
    """高峰时用 enqueue，由队列按 max_concurrency 派发。"""
    base_url = kwargs["base_url"].rstrip("/")
    token = kwargs.get("token")
    dag_file = kwargs.get("dag_file", "code-review")
    repo = kwargs["repo"]
    pr_number = kwargs["pr_number"]
    run_id = f"cr-{repo.replace('/', '-')}-pr{pr_number}-{int(time.time())}"

    params_obj = {
        "repo": repo,
        "pr_number": str(pr_number),
        "base_branch": kwargs.get("base_branch", "main"),
        "head_sha": kwargs.get("head_sha", ""),
        "review_mode": kwargs.get("review_mode", "full"),
        "enable_security": kwargs.get("enable_security", "true"),
        "notify_feishu": kwargs.get("notify_feishu", "true"),
        "feishu_chat_id": kwargs.get("feishu_chat_id", ""),
    }
    body = {
        "params": json.dumps(params_obj, ensure_ascii=False),
        "dagRunId": run_id,
        "singleton": False,
    }
    url = f"{base_url}/api/v1/dags/{dag_file}/enqueue"
    result = _request("POST", url, token=token, body=body)
    result.setdefault("dagRunId", run_id)
    return result


def main() -> int:
    p = argparse.ArgumentParser(description="Trigger Code Review via Dagu Hub API")
    p.add_argument("--base-url", default=os.getenv("DAGU_BASE_URL", "http://127.0.0.1:8080"))
    p.add_argument("--token", default=os.getenv("DAGU_API_TOKEN"))
    p.add_argument("--repo", required=True)
    p.add_argument("--pr", required=True, dest="pr_number")
    p.add_argument("--base-branch", default="main")
    p.add_argument("--head-sha", default="")
    p.add_argument("--mode", default="full", choices=["full", "quick", "security-only"])
    p.add_argument("--enqueue", action="store_true", help="Use /enqueue instead of /start")
    p.add_argument("--wait", action="store_true", help="Poll until terminal status")
    args = p.parse_args()

    common = dict(
        base_url=args.base_url,
        token=args.token,
        repo=args.repo,
        pr_number=args.pr_number,
        base_branch=args.base_branch,
        head_sha=args.head_sha,
        review_mode=args.mode,
    )

    if args.enqueue:
        result = enqueue_code_review(**common)
    else:
        result = trigger_code_review(**common)

    print(json.dumps(result, ensure_ascii=False, indent=2))
    run_id = result.get("dagRunId") or result.get("dag_run_id")
    if args.wait and run_id:
        for _ in range(120):
            st = get_run_status(
                base_url=args.base_url,
                token=args.token,
                dag_file="code-review",
                dag_run_id=run_id,
            )
            status = (
                st.get("status")
                or st.get("dagRun", {}).get("status")
                or st.get("Result", {}).get("status")
            )
            print(f"status={status}", file=sys.stderr)
            if status in {"succeeded", "failed", "aborted", "cancelled", "partially_succeeded"}:
                print(json.dumps(st, ensure_ascii=False, indent=2))
                return 0 if status == "succeeded" else 1
            time.sleep(5)
        print("timeout waiting for run", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

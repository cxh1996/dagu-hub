# dagu-hub — 统一工作站 + 独立 Worker 隔离

基于 [Dagu](https://docs.dagu.sh/) 官方分布式能力的自动化编排基座：一个总工作站（UI / API / 调度 / Coordinator），多个业务 Worker 进程隔离执行与落库。

## 你需要的六件事

| # | 交付物 | 位置 |
|---|--------|------|
| 1 | 整体架构说明 | [docs/architecture.md](docs/architecture.md) |
| 2 | PM2 `ecosystem.config.js` | [ecosystem.config.js](ecosystem.config.js) |
| 3 | Code Review DAG（条件 / 并行 / 多依赖） | [dags/code-review/code-review.yaml](dags/code-review/code-review.yaml) |
| 4 | 飞书 / 外部系统触发 API 示例 | [scripts/feishu/](scripts/feishu/) |
| 5 | Worker 标签与 `worker_selector` 建议 | [docs/worker-labels.md](docs/worker-labels.md) |
| 6 | 主进程重启不影响 Worker 任务 | [docs/restart-isolation.md](docs/restart-isolation.md) |

---

## 1. 整体架构

```
飞书机器人 / Agent / CI
        │  REST API
        ▼
┌───────────────────────────────────┐
│  dagu-hub（dagu start-all）        │
│  Web UI :8080 · API · Scheduler   │
│  Coordinator gRPC :50055          │
│  ./dags 全部 DAG 定义              │
└─────────────────┬─────────────────┘
                  │ worker_selector 派发
      ┌───────────┼───────────┐
      ▼           ▼           ▼
 code-review   knowledge   issue-track ...
 Worker        Worker      Worker
 独立 data/    独立 data/   独立 data/
```

- **统一入口**：只打主实例 API / Web UI。
- **执行隔离**：DAG 顶部 `worker_selector.role` 路由到对应 `dagu worker`。
- **数据隔离**：业务记录写在 `workers/<biz>/data`，主实例只存编排状态与回传日志。
- **多实例**：全局队列 `max_concurrency` + API `singleton: false`。

详见 [docs/architecture.md](docs/architecture.md)。

---

## 2. 快速启动（PM2）

前置：安装 [Dagu](https://docs.dagu.sh/) 与 PM2（`npm i -g pm2`）。

```bash
chmod +x scripts/code-review/*.sh scripts/feishu/*.sh
pm2 start ecosystem.config.js
pm2 status
```

等价手工命令：

```bash
# 主工作站
dagu start-all --coordinator.host=0.0.0.0 --dags=./dags

# Code Review Worker
dagu worker \
  --worker.labels role=code-review,biz=code-review,tier=default \
  --worker.coordinators=127.0.0.1:50055
```

仅重启看板（Worker 继续跑）：

```bash
pm2 restart dagu-hub
```

---

## 3. Code Review DAG 要点

文件：[dags/code-review/code-review.yaml](dags/code-review/code-review.yaml)

| 能力 | 用法 |
|------|------|
| Worker 路由 | `worker_selector.role: code-review` |
| 条件判断 | `preconditions` + `negate`（如跳过 quick 模式的 lint） |
| 并行扇出 | `action: dag.run` + `parallel.items` 按文件评审 |
| 循环等待 | `repeat_policy` 轮询合规策略 |
| 多输入汇聚 | `depends: [run_lint, review_files, security_review, ...]` |
| 同 DAG 多实例 | `queue: code-review`（`max_concurrency: 20`） |

子 DAG：[dags/code-review/code-review-file-review.yaml](dags/code-review/code-review-file-review.yaml)

业务脚本（可替换为真实 lint / LLM / gh）：[scripts/code-review/](scripts/code-review/)

---

## 4. 触发示例

### curl

```bash
export DAGU_BASE_URL=http://127.0.0.1:8080
./scripts/feishu/curl_examples.sh org/demo-app 101
```

### Python（飞书 / Agent）

```bash
python3 scripts/feishu/trigger_code_review.py \
  --repo org/demo-app --pr 101 --mode full
```

### Node 飞书指令

见 [scripts/feishu/bot_handler.example.js](scripts/feishu/bot_handler.example.js) — 解析 `/review org/repo#123` 后调用：

`POST /api/v1/dags/code-review/start`

```json
{
  "params": "{\"repo\":\"org/app\",\"pr_number\":\"123\",\"review_mode\":\"full\"}",
  "dagRunId": "cr-org-app-pr123-1710000000",
  "singleton": false
}
```

高峰也可用 `POST /api/v1/dags/code-review/enqueue`。

---

## 5. 标签约定（摘要）

```yaml
# DAG
worker_selector:
  role: code-review
```

```bash
# Worker
--worker.labels role=code-review,biz=code-review,tier=default
```

完整矩阵见 [docs/worker-labels.md](docs/worker-labels.md)。

---

## 6. 主重启 vs Worker

PM2 按 name 独立管理：重启 `dagu-hub` **不会**杀掉 `dagu-worker-code-review`。已在跑的步骤继续执行，日志/状态在 Coordinator 恢复后回传 UI。细节与加固建议见 [docs/restart-isolation.md](docs/restart-isolation.md)。

---

## 目录结构

```
├── config/dagu.yaml              # 主实例配置（队列 / coordinator）
├── ecosystem.config.js           # PM2：hub + workers
├── dags/
│   ├── code-review/              # Code Review 主/子 DAG
│   └── knowledge/                # 后续业务占位
├── scripts/
│   ├── code-review/              # Worker 侧步骤脚本
│   └── feishu/                   # API / 飞书触发示例
├── workers/
│   ├── code-review/{data,logs}/  # 业务数据隔离
│   └── knowledge/{data,logs}/
└── docs/                         # 架构与运维说明
```

## 后续业务接入

对知识库 / 问答 / Beta / 问题单：复制 Code Review 模式 —— 新 DAG + `worker_selector.role` + 队列 + 新 PM2 Worker + 独立 `workers/<biz>/data`。占位示例：[dags/knowledge/knowledge-build.placeholder.yaml](dags/knowledge/knowledge-build.placeholder.yaml)。

# 统一工作站 + 独立 Worker 隔离架构

## 1. 目标

用 Dagu 作为长期编排基座，替代 Claude Code JS Workflow：

| 能力 | 实现方式 |
|------|----------|
| 统一入口 / 看板 / 触发 | 主实例 `dagu start-all`（Web UI + REST API + Scheduler + Coordinator） |
| 业务进程隔离 | 每个业务一个 `dagu worker`，由 PM2 独立托管 |
| 业务数据隔离 | 各 Worker 使用独立 `WORKER_DATA_DIR`，互不读写 |
| 复杂控制流 | DAG YAML：`preconditions` / `depends` / `parallel` / `repeat_policy` |
| 同 DAG 多实例 | 全局队列 `max_concurrency` + `singleton: false` |

## 2. 拓扑

```
                    ┌─────────────────────────────────────┐
  飞书 / Agent ───► │  主 Dagu（dagu-hub）                  │
                    │  · Web UI :8080                      │
                    │  · REST API                          │
                    │  · Scheduler / Queue                 │
                    │  · Coordinator gRPC :50055           │
                    │  · 所有 DAG YAML（./dags）            │
                    └──────────────┬──────────────────────┘
                                   │ gRPC 派发 / 状态 / 日志回传
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                    ▼
     Worker code-review    Worker knowledge      Worker issue-track
     labels:               labels:               labels:
       role=code-review      role=knowledge-build  role=issue-track
     data/: 独立记录         data/: 独立记录         data/: 独立记录
```

### 数据流（Shared-Nothing）

1. 外部调用主 API：`POST /api/v1/dags/{fileName}/start`（或 enqueue / webhook）
2. 主实例入队 → Queue 按 `max_concurrency` 出队
3. Coordinator 按 DAG 的 `worker_selector` 匹配 Worker 标签，派发任务（含 DAG 定义快照）
4. Worker 在本机执行；业务记录写入本 Worker 的 `WORKER_DATA_DIR`
5. Worker 通过 gRPC `ReportStatus` / `StreamLogs` 实时回传；主 Web UI 完整展示图形、进度、日志、历史

Worker **不需要**挂载主实例的 `dags/` 或 `data/`；脚本与依赖通过 `dependencies` 随任务快照下发，或在 Worker 镜像/目录中预置。

## 3. 进程职责边界

| 进程 | PM2 name | 职责 | 重启影响 |
|------|----------|------|----------|
| 主控面 | `dagu-hub` | UI、API、调度、协调、DAG 定义托管 | 短暂中断触发与看板；**不杀** Worker 进程 |
| Code Review Worker | `dagu-worker-code-review` | 只执行 `role=code-review` 的 DAG | 仅影响本业务；排水超时后取消本机任务 |
| Knowledge Worker | `dagu-worker-knowledge` | 知识库相关 DAG | 同上 |

## 4. Worker 标签与 `worker_selector`

### 建议标签约定

| Key | 含义 | 示例 |
|-----|------|------|
| `role` | 业务路由主键（必选） | `code-review` / `knowledge-build` / `knowledge-qa` / `beta-handle` / `issue-track` |
| `biz` | 业务线（便于扩展筛选） | `code-review` / `knowledge` |
| `tier` | 容量分层 | `default` / `heavy` |

### DAG 侧

```yaml
worker_selector:
  role: code-review
```

匹配规则（官方）：selector 中**每一个** kv 都必须在 Worker labels 中**精确相等**；Worker 可有多余标签。

### 禁止事项

- 业务 DAG **不要**省略 `worker_selector`（否则默认在主实例本地跑）
- 不要把多个互斥业务打到同一 `role` 标签
- 主实例健康检查类 DAG 可用 `worker_selector: local` 强制本地

## 5. 主进程重启 vs Worker 任务

### 为何互不影响（进程层）

PM2 按 **app name** 独立管理。`pm2 restart dagu-hub` 只向主进程发信号，**不会**停止 `dagu-worker-*`。正在执行的步骤继续在 Worker OS 进程树中运行。

### Coordinator 短暂不可用时

Worker 侧：

- 本地步骤继续执行
- 日志在 Coordinator 宕机期间最多缓存约 **16 MiB**/流，并在恢复后重传
- Heartbeat / 状态推送在连上后恢复

主实例侧注意：

- Coordinator 与 Web 同在 `start-all` 时，主重启 = Coordinator 短暂下线
- 若宕机过久，Coordinator 的僵尸检测可能把失联任务标失败；**生产建议**：
  1. 主重启尽量用滚动/快速重启（秒级）
  2. 或把 `dagu coordinator` 拆成独立 PM2 进程，Web/API 可单独重启
  3. `paths.data_dir` / `dag-state` 落在持久磁盘，避免主重启丢历史与状态

### 运维口令

```bash
# 只重启看板与 API（Worker 继续跑）
pm2 restart dagu-hub

# 优雅停某个 Worker（先排水）
pm2 stop dagu-worker-code-review

# 扩容同标签 Worker（再加一台机器或再起一个 worker.id）
pm2 start ecosystem.config.js --only dagu-worker-code-review
```

## 6. 同 DAG 多实例

- Code Review DAG 挂到全局队列 `queue: code-review`，`max_concurrency: 20`
- API 触发时使用不同 `dagRunId`（如 `cr-{repo}-{pr}-{ts}`），且 **不要** 设 `singleton: true`
- 各实例参数不同（`repo` / `pr_number`），在 Worker 内按 run 目录隔离数据

## 7. 后续业务接入模板

对每个新业务重复：

1. 在 `dags/<biz>/` 增加 YAML，顶部写 `worker_selector.role: <biz>`
2. 在 `config/dagu.yaml` 增加队列
3. 在 `ecosystem.config.js` 增加对应 `dagu worker` app 与独立 `workers/<biz>/data`
4. 飞书 / Agent 只调用主 API，不直连 Worker

## 8. Dagu 2.x 编写注意

- **入口 DAG 不要写顶层 `name`**：名称取自文件名（如 `code-review.yaml` → `code-review`）。同文件内用 `---` 分隔的子文档才写 `name:`。
- 建议写 `type: graph`。
- 步骤可用 `id` + `name`；跨步骤输出引用形如 `${filter_paths.outputs.file_list}`。
- 脚本向 `DAGU_OUTPUT_FILE` 写 `key=value`（多行用 `key<<EOF`）。

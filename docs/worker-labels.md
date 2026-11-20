# Worker 标签与 `worker_selector` 配置建议

## 匹配规则（官方）

1. Selector 中**每个** key=value 都必须在 Worker labels 中**精确相等**（大小写敏感）
2. Worker 可以有多余标签
3. 空 selector：可匹配任意 Worker（本项目业务 DAG **禁止**空 selector）
4. `worker_selector: local`：强制在主实例本地执行

## 推荐标签字典

| Key | 用途 | 取值约定 |
|-----|------|----------|
| `role` | **路由主键** | `code-review` / `knowledge-build` / `knowledge-qa` / `beta-handle` / `issue-track` |
| `biz` | 业务线聚合 | 与 role 同族，便于运维筛选 |
| `tier` | 容量档 | `default` / `heavy` |
| `region` | 多机房（可选） | `cn-hz` / `us-east` |

## 业务对照表

| 业务 | Worker labels | DAG `worker_selector` | 队列名 |
|------|---------------|----------------------|--------|
| Code Review | `role=code-review,biz=code-review,tier=default` | `role: code-review` | `code-review` |
| 知识库构建 | `role=knowledge-build,biz=knowledge` | `role: knowledge-build` | `knowledge-build` |
| 知识问答 | `role=knowledge-qa,biz=knowledge` | `role: knowledge-qa` | `knowledge-qa` |
| Beta 处理 | `role=beta-handle,biz=beta` | `role: beta-handle` | `beta-handle` |
| 问题单跟踪 | `role=issue-track,biz=issue` | `role: issue-track` | `issue-track` |

## 扩容模式

同 `role` 起多个 Worker（不同 `--worker.id`），Coordinator 会在匹配的健康 Worker 间派发：

```bash
dagu worker \
  --worker.coordinators=127.0.0.1:50055 \
  --worker.labels role=code-review,biz=code-review,tier=default \
  --worker.id=code-review-2 \
  --worker.max-active-runs=10
```

重活可单独打 `tier=heavy`，对应 DAG：

```yaml
worker_selector:
  role: code-review
  tier: heavy
```

## API 运行时覆盖

```json
{
  "params": "{\"repo\":\"org/app\",\"pr_number\":\"1\"}",
  "workerSelector": { "role": "code-review", "tier": "heavy" }
}
```

会**替换**该次运行的 DAG 级 `worker_selector`（含重试）。

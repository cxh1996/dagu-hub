# 主进程重启不影响 Worker 任务

## 结论

在本仓库的 PM2 拓扑下：

1. **进程隔离**：`dagu-hub` 与 `dagu-worker-*` 是独立 PM2 app。`pm2 restart dagu-hub` 不会向 Worker 发 SIGTERM。
2. **执行继续**：已派发到 Worker 的 DAG 步骤在 Worker 本机进程树中继续跑；业务数据写在 `workers/<biz>/data`。
3. **状态/日志回传**：Worker 通过 gRPC 向 Coordinator 推送 `ReportStatus` / `StreamLogs`。主 Web UI 读的是主实例侧状态，因此恢复连通后看板会追上进度。

## 操作示例

```bash
# 只重启统一工作站（UI / API / Scheduler / Coordinator）
pm2 restart dagu-hub

# Worker 列表应仍为 online，任务不中断
pm2 list
pm2 show dagu-worker-code-review
```

## 短暂 Coordinator 不可用时发生什么

| 侧面 | 行为 |
|------|------|
| Worker 本地执行 | 继续 |
| 日志 | 宕机期间缓存（约 16MiB/流），恢复后重传 |
| Heartbeat | 恢复后继续；过久失联时 Coordinator 可能把任务标为僵尸失败 |

因此生产上建议：

- 主重启尽量秒级完成
- `config/dagu.yaml` 的 `paths.data_dir` 使用持久磁盘
- 若需频繁重启 Web/API，把 `dagu coordinator` 拆成独立 PM2 进程，与 `dagu-hub`（仅 UI）分离

## 拆分 Coordinator（可选加固）

```js
// ecosystem 片段示意
{
  name: "dagu-coordinator",
  script: "dagu",
  args: ["coordinator", "--coordinator.host=0.0.0.0", "--coordinator.port=50055"],
},
{
  name: "dagu-hub",
  // 若单独跑 web+scheduler，需关闭内置 coordinator，避免端口冲突
  // env: { DAGU_COORDINATOR_ENABLED: "false" }
}
```

Worker 的 `--worker.coordinators` 始终指向**稳定的** Coordinator 地址。

## Worker 自身重启

```bash
pm2 stop dagu-worker-code-review   # 先排水（shutdown-timeout=300s）
pm2 restart dagu-worker-code-review
```

Worker 重启会影响**该 Worker 上**未完成的任务；其他业务 Worker 与主控面不受影响。

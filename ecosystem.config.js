/**
 * PM2 进程编排：主工作站 + 独立业务 Worker
 *
 * 启动：
 *   pm2 start ecosystem.config.js
 *
 * 仅重启主控面（不影响 Worker 上正在跑的任务）：
 *   pm2 restart dagu-hub
 *
 * 查看 Worker：
 *   pm2 list
 *   pm2 logs dagu-worker-code-review
 */

const path = require("path");

const ROOT = __dirname;
const COORDINATOR = process.env.DAGU_COORDINATOR || "127.0.0.1:50055";

module.exports = {
  apps: [
    // ──────────────────────────────────────────────
    // 总工作站：Web UI + REST API + Scheduler + Coordinator
    // ──────────────────────────────────────────────
    {
      name: "dagu-hub",
      script: "dagu",
      args: [
        "start-all",
        "--host=0.0.0.0",
        "--port=8080",
        `--dags=${path.join(ROOT, "dags")}`,
        "--coordinator.host=0.0.0.0",
        "--coordinator.port=50055",
        // 多机时改为 Worker 可达地址，例如 --coordinator.advertise=10.0.0.5
      ],
      cwd: ROOT,
      instances: 1,
      autorestart: true,
      max_restarts: 20,
      min_uptime: "10s",
      kill_timeout: 15000,
      env: {
        DAGU_HOME: path.join(ROOT, "data", "hub"),
        DAGU_CONFIG: path.join(ROOT, "config", "dagu.yaml"),
        // 业务脚本可读；主进程本身不跑业务
        DAGU_ROLE: "hub",
      },
    },

    // ──────────────────────────────────────────────
    // Code Review Worker（独立进程 / 独立数据目录）
    // ──────────────────────────────────────────────
    {
      name: "dagu-worker-code-review",
      script: "dagu",
      args: [
        "worker",
        `--worker.coordinators=${COORDINATOR}`,
        "--worker.labels",
        "role=code-review,biz=code-review,tier=default",
        "--worker.id=code-review-1",
        "--worker.max-active-runs=10",
        "--worker.health-port=8092",
        // 优雅停机：给正在跑的任务留排水时间
        "--worker.shutdown-timeout=300s",
        "--peer.insecure",
      ],
      cwd: path.join(ROOT, "workers", "code-review"),
      instances: 1,
      autorestart: true,
      max_restarts: 50,
      min_uptime: "5s",
      // 重启主进程时不要连带重启 Worker
      // （PM2 默认按 name 独立管理，这里显式注释提醒）
      kill_timeout: 320000,
      env: {
        DAGU_ROLE: "worker",
        DAGU_BIZ: "code-review",
        // 业务数据隔离：只写本 Worker 目录
        WORKER_DATA_DIR: path.join(ROOT, "workers", "code-review", "data"),
        WORKER_LOG_DIR: path.join(ROOT, "workers", "code-review", "logs"),
        // 脚本路径（DAG 内通过 env 引用）
        SCRIPTS_DIR: path.join(ROOT, "scripts", "code-review"),
        PATH: process.env.PATH,
      },
    },

    // ──────────────────────────────────────────────
    // 知识库构建 Worker（ENABLE_KNOWLEDGE_WORKER=1 时启用）
    //   ENABLE_KNOWLEDGE_WORKER=1 pm2 start ecosystem.config.js
    // ──────────────────────────────────────────────
    ...(process.env.ENABLE_KNOWLEDGE_WORKER === "1"
      ? [
          {
            name: "dagu-worker-knowledge",
            script: "dagu",
            args: [
              "worker",
              `--worker.coordinators=${COORDINATOR}`,
              "--worker.labels",
              "role=knowledge-build,biz=knowledge,tier=default",
              "--worker.id=knowledge-1",
              "--worker.max-active-runs=5",
              "--worker.health-port=8093",
              "--worker.shutdown-timeout=300s",
              "--peer.insecure",
            ],
            cwd: path.join(ROOT, "workers", "knowledge"),
            instances: 1,
            autorestart: true,
            kill_timeout: 320000,
            env: {
              DAGU_ROLE: "worker",
              DAGU_BIZ: "knowledge",
              WORKER_DATA_DIR: path.join(ROOT, "workers", "knowledge", "data"),
              WORKER_LOG_DIR: path.join(ROOT, "workers", "knowledge", "logs"),
              SCRIPTS_DIR: path.join(ROOT, "scripts"),
              PATH: process.env.PATH,
            },
          },
        ]
      : []),
  ],
};

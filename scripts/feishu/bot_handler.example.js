/**
 * 飞书机器人事件处理示例（Node.js）
 *
 * 流程：飞书卡片/指令 → 解析 repo/PR → 调用主 Dagu API 触发 code-review DAG
 * 注意：只打主工作站 API，不要直连 Worker。
 */

const DAGU_BASE_URL = process.env.DAGU_BASE_URL || "http://127.0.0.1:8080";
const DAGU_API_TOKEN = process.env.DAGU_API_TOKEN || "";

/**
 * @param {{ repo: string, prNumber: number|string, chatId?: string, mode?: string }} input
 */
async function startCodeReview(input) {
  const dagRunId = `cr-${input.repo.replaceAll("/", "-")}-pr${input.prNumber}-${Date.now()}`;
  const params = {
    repo: input.repo,
    pr_number: String(input.prNumber),
    base_branch: input.baseBranch || "main",
    head_sha: input.headSha || "",
    review_mode: input.mode || "full",
    enable_security: "true",
    notify_feishu: "true",
    feishu_chat_id: input.chatId || "",
  };

  const res = await fetch(`${DAGU_BASE_URL}/api/v1/dags/code-review/start`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(DAGU_API_TOKEN ? { Authorization: `Bearer ${DAGU_API_TOKEN}` } : {}),
    },
    body: JSON.stringify({
      params: JSON.stringify(params),
      dagRunId,
      singleton: false,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Dagu start failed: ${res.status} ${text}`);
  }
  return { dagRunId, ...(await res.json()) };
}

/**
 * 飞书「接收消息」回调里调用
 * 指令约定：/review org/repo#123
 */
async function onFeishuMessage(event) {
  const text = event?.message?.content_text || "";
  const m = text.match(/\/review\s+([A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+)#(\d+)/);
  if (!m) {
    return { reply: "用法：/review org/repo#123" };
  }
  const [, repo, prNumber] = m;
  const chatId = event?.message?.chat_id || "";
  const result = await startCodeReview({ repo, prNumber, chatId });
  return {
    reply: `已触发 Code Review\nrepo=${repo} PR=#${prNumber}\nrun=${result.dagRunId}\n看板：${DAGU_BASE_URL}`,
  };
}

module.exports = { startCodeReview, onFeishuMessage };

// 本地快速试跑：
//   node -e 'require("./bot_handler.example.js").startCodeReview({repo:"org/app",prNumber:1}).then(console.log)'

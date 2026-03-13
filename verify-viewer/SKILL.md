---
name: verify-viewer
description: Set up project verification with verify-viewer. Use when the user wants to add verification to a project, write a verify script, configure verify.md frontmatter, or debug verification results.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: "[action: setup|write-script|check-results]"
---

# verify-viewer 项目验证接入技能

你是一个 verify-viewer 验证框架的配置专家。帮助用户为项目接入统一验证系统。

## 核心知识

- verify-viewer 是通用验证执行器 + Web 仪表板
- 项目通过 `verify.md` 的 YAML frontmatter 声明验证命令和结果文件
- 验证结果是 JSON 数组，每次追加一条记录
- 结果中的 `html` 字段直接 innerHTML 插入前端页面

## 接入操作流程

### 1. 创建 verify.md

在项目根目录创建 `verify.md`，写入 frontmatter：

```yaml
---
verify:
  command: "node scripts/verify.js"
  resultsFile: "verify-results.json"
---

# 验证清单
（正文 Markdown 会在前端「文档」tab 中展示）
```

- `command`（必填）：在项目 cwd 下执行的验证命令
- `resultsFile`（必填）：结果文件路径，相对于项目 cwd
- 缺少 `command` 时前端 Run Verify 按钮禁用

### 2. 编写验证脚本

脚本要求：
- 在项目 cwd 下可执行，超时 120 秒
- 执行检查逻辑后，将结果**追加**到 `resultsFile` 的 JSON 数组中

### 3. 结果文件格式

每条记录的字段：

```json
{
  "id": "m1abc2def",
  "timestamp": "2026-03-07T12:00:00.000Z",
  "pass": true,
  "html": "<div class='verify-grid'>...</div>"
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 唯一标识，推荐 `Date.now().toString(36)` |
| `timestamp` | string | ISO 8601 时间戳 |
| `pass` | boolean | 是否全部通过（前端 PASS/FAIL 徽章） |
| `html` | string | 展示 HTML，直接嵌入页面 |

## 可用 CSS Class

生成 `html` 时可复用这些 class 保持视觉一致：

| Class | 用途 |
|-------|------|
| `.verify-grid` | 2 列网格容器（移动端 1 列） |
| `.verify-svc` | 检查卡片 |
| `.verify-svc-name` | 卡片标题 |
| `.verify-svc-row` | 一行检查项 |
| `.verify-dot.ok` | 绿色圆点 |
| `.verify-dot.fail` | 红色圆点 |
| `.verify-svc-label` | 标签（灰色） |
| `.verify-svc-value` | 值 |
| `.verify-svc-ms` | 辅助信息（小号灰色） |

## Node.js 验证脚本模板

当用户需要编写验证脚本时，基于以下模板生成：

```js
const fs = require("fs");
const path = require("path");
const RESULTS_FILE = path.join(__dirname, "verify-results.json");

async function run() {
  const checks = [
    // { name: "检查名", ok: true/false, detail: "描述" }
  ];
  const allPass = checks.every(c => c.ok);

  let html = '<div class="verify-grid">';
  for (const c of checks) {
    html += `<div class="verify-svc">`;
    html += `<div class="verify-svc-name">${c.name}</div>`;
    html += `<div class="verify-svc-row">`;
    html += `<span class="verify-dot ${c.ok ? "ok" : "fail"}"></span>`;
    html += `<span class="verify-svc-value">${c.detail}</span>`;
    html += `</div></div>`;
  }
  html += "</div>";

  const history = (() => {
    try { return JSON.parse(fs.readFileSync(RESULTS_FILE, "utf-8")); }
    catch { return []; }
  })();
  history.push({ id: Date.now().toString(36), timestamp: new Date().toISOString(), pass: allPass, html });
  if (history.length > 100) history.splice(0, history.length - 100);
  fs.writeFileSync(RESULTS_FILE, JSON.stringify(history, null, 2), "utf-8");
  process.exit(allPass ? 0 : 1);
}
run();
```

## 注意事项

- `resultsFile` 由验证脚本写入，verify-viewer 只读取
- 建议将 `verify-results.json` 加入 `.gitignore`
- 退出码不影响结果展示（以 `pass` 字段为准），但 `exit 0/1` 有助于 CI
- 建议只保留最近 100 条结果

详细说明、Bash 模板和发现机制见 [README.md](README.md)。

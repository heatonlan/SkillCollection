# verify-viewer - 通用项目验证框架

统一的验证执行器和结果展示器。任何项目只需按约定配置 `verify.md`，即可接入自动验证并在 Web 仪表板中查看结果。

## 适用场景

- 多项目统一验证入口，一个仪表板查看所有项目的验证状态
- 验证结果持久化，支持历史回溯和趋势查看
- 自定义验证逻辑，不限语言和框架

## 前置条件

- Node.js 运行环境
- 被验证项目需要有可执行的验证脚本

---

## 架构概览

```
verify-viewer（Web 仪表板）
  ↓ 发现机制
tabs.json / dynamic-tabs.json → 各项目 cwd
  ↓ 检查
cwd/verify.md 是否存在？
  ↓ 解析
frontmatter → command / resultsFile
  ↓ 执行
在项目 cwd 下运行 command
  ↓ 读取
resultsFile（JSON 数组）→ 前端渲染
```

---

## 接入方式（3 步）

### 第一步：创建 verify.md

在项目根目录创建 `verify.md`，顶部添加 YAML frontmatter：

```yaml
---
verify:
  command: "node scripts/verify.js"
  resultsFile: "verify-results.json"
---

# 验证清单

这里写项目的验证文档（Markdown），
会在 verify-viewer 的「文档」tab 中渲染展示。
```

| 字段 | 必填 | 说明 |
|------|------|------|
| `command` | 是 | 在项目 cwd 下执行的验证命令（任意可执行命令） |
| `resultsFile` | 是 | 结果文件路径，相对于项目 cwd |

- 缺少 `command` 时，前端 Run Verify 按钮自动禁用
- frontmatter 之后的 Markdown 正文作为文档展示在前端

### 第二步：编写验证脚本

验证脚本可以是任意语言，只需满足：

1. 在项目 cwd 下可执行（`command` 会以 `cwd` 为工作目录运行）
2. 执行完毕后将结果**追加**到 `resultsFile` 指定的 JSON 文件
3. 超时限制：120 秒

### 第三步：输出结果文件

`resultsFile` 是一个 **JSON 数组**，每次运行追加一条记录：

```json
[
  {
    "id": "m1abc2def",
    "timestamp": "2026-03-07T12:00:00.000Z",
    "pass": true,
    "html": "<div class='verify-grid'>...</div>"
  }
]
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 唯一标识，推荐 `Date.now().toString(36)` |
| `timestamp` | string | ISO 8601 时间戳 |
| `pass` | boolean | 本次验证是否全部通过（前端 PASS/FAIL 徽章） |
| `html` | string | 展示用 HTML 片段，verify-viewer 直接 `innerHTML` 插入 |

---

## HTML 片段与 CSS Class

`html` 字段由验证脚本自行生成，verify-viewer 直接嵌入页面。可复用内置 CSS class 保持视觉一致：

```html
<div class="verify-grid">
  <div class="verify-svc">
    <div class="verify-svc-name">服务名称</div>
    <div class="verify-svc-row">
      <span class="verify-dot ok"></span>
      <span class="verify-svc-label">检查项</span>
      <span class="verify-svc-value">200</span>
      <span class="verify-svc-ms">45ms</span>
    </div>
  </div>
</div>
```

| Class | 用途 |
|-------|------|
| `.verify-grid` | 2 列网格容器（移动端自动 1 列） |
| `.verify-svc` | 单个检查卡片 |
| `.verify-svc-name` | 卡片标题 |
| `.verify-svc-row` | 一行检查项 |
| `.verify-dot.ok` | 绿色圆点（通过） |
| `.verify-dot.fail` | 红色圆点（失败） |
| `.verify-svc-label` | 标签文字（灰色） |
| `.verify-svc-value` | 值文字 |
| `.verify-svc-ms` | 辅助信息（小号灰色） |

也可使用自定义 HTML + inline style，不强制使用上述 class。

---

## 验证脚本模板

### Node.js 模板

```js
const fs = require("fs");
const path = require("path");

const RESULTS_FILE = path.join(__dirname, "verify-results.json");

async function run() {
  // ── 执行检查逻辑 ──
  const checks = [
    { name: "API 健康检查", ok: true, detail: "200 OK (32ms)" },
    { name: "数据库连接",   ok: true, detail: "connected" },
  ];

  const allPass = checks.every(c => c.ok);

  // ── 生成 HTML ──
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

  // ── 写入结果 ──
  const history = (() => {
    try { return JSON.parse(fs.readFileSync(RESULTS_FILE, "utf-8")); }
    catch { return []; }
  })();

  history.push({
    id: Date.now().toString(36),
    timestamp: new Date().toISOString(),
    pass: allPass,
    html,
  });

  // 只保留最近 100 条
  if (history.length > 100) history.splice(0, history.length - 100);
  fs.writeFileSync(RESULTS_FILE, JSON.stringify(history, null, 2), "utf-8");

  process.exit(allPass ? 0 : 1);
}

run();
```

### Bash 模板

```bash
#!/bin/bash
RESULTS_FILE="verify-results.json"
PASS=true
HTML='<div class="verify-grid">'

# ── 检查逻辑 ──
if curl -sf http://localhost:3000 > /dev/null; then
  HTML+='<div class="verify-svc"><div class="verify-svc-row"><span class="verify-dot ok"></span><span class="verify-svc-value">Service OK</span></div></div>'
else
  HTML+='<div class="verify-svc"><div class="verify-svc-row"><span class="verify-dot fail"></span><span class="verify-svc-value">Service Down</span></div></div>'
  PASS=false
fi

HTML+='</div>'

# ── 写入结果 ──
ID=$(date +%s | awk '{printf "%s", strftime("%s",$1)}' | xargs printf '%x')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
ENTRY="{\"id\":\"$ID\",\"timestamp\":\"$TIMESTAMP\",\"pass\":$PASS,\"html\":\"$(echo "$HTML" | sed 's/"/\\"/g')\"}"

if [ -f "$RESULTS_FILE" ]; then
  # 追加到已有数组
  TMP=$(mktemp)
  jq ". + [$ENTRY]" "$RESULTS_FILE" > "$TMP" && mv "$TMP" "$RESULTS_FILE"
else
  echo "[$ENTRY]" > "$RESULTS_FILE"
fi
```

---

## 发现机制

verify-viewer 通过 web-terminal 的 `tabs.json` / `dynamic-tabs.json` 发现项目目录：

```
tabs.json 中的 cwd
  → 检查 cwd/verify.md 是否存在
    → 存在：解析 frontmatter 获取 command / resultsFile
    → 前端展示项目，可查看文档、触发验证、查看结果
```

---

## 注意事项

1. `resultsFile` 由验证脚本自行写入，verify-viewer 只读取
2. 验证命令的 stdout/stderr 会在 API 响应中返回，但不展示在前端
3. 建议将 `verify-results.json` 加入 `.gitignore`
4. 退出码不影响结果展示（结果以 `pass` 字段为准），但 `exit 0/1` 有助于 CI 集成
5. 建议每次验证结果只保留最近 100 条，防止文件膨胀

# MCP 与 API 本质区别

帮助理解 MCP（Model Context Protocol）和传统 API 的核心差异，以及各自的适用场景。

## 目录

- [一句话理解](#一句话理解)
- [背景：为什么需要 MCP](#背景为什么需要-mcp)
- [核心对比表](#核心对比表)
- [MCP 协议架构](#mcp-协议架构)
- [MCP 三大原语](#mcp-三大原语)
- [五个本质区别](#五个本质区别)
- [选型指南](#选型指南)
- [MCP 实现指南](#mcp-实现指南)
- [常见误区](#常见误区)

## 一句话理解

**API 是"人写代码调接口"；MCP 是"AI 自己发现并调用能力"。**

## 背景：为什么需要 MCP

传统模式下，让 AI 访问外部工具需要为每一对（AI 客户端, 外部服务）写一套定制集成代码。如果有 N 个 AI 客户端和 M 个外部服务，就需要 **N × M** 套适配代码。

MCP 提出一个标准协议：所有 AI 客户端用同一种方式连接所有 MCP server，集成成本降为 **N + M**。

```
传统方式                          MCP 方式
┌────────┐                       ┌────────┐
│ AI - A │──┐                    │ AI - A │──┐
└────────┘  │  定制代码           └────────┘  │
┌────────┐  ├──→ 服务 1          ┌────────┐  ├──→ MCP Server 1
│ AI - B │──┤  定制代码           │ AI - B │──┤     (标准协议)
└────────┘  ├──→ 服务 2          └────────┘  ├──→ MCP Server 2
┌────────┐  │  定制代码           ┌────────┐  │     (标准协议)
│ AI - C │──┘──→ 服务 3          │ AI - C │──┘──→ MCP Server 3
└────────┘                       └────────┘
  N×M 集成                         N+M 集成
```

## 核心对比表

| 维度 | 传统 API（REST / GraphQL / gRPC） | MCP（Model Context Protocol） |
|------|-----------------------------------|-------------------------------|
| **设计受众** | 开发者（人） | AI 模型（LLM） |
| **发现方式** | 开发者阅读文档、手写调用代码 | AI 运行时自动发现 server 暴露的 tools / resources |
| **调用方式** | 客户端代码硬编码 endpoint + 参数 | AI 根据 JSON Schema 动态决定参数并调用 |
| **协议层** | HTTP / gRPC / WebSocket | JSON-RPC 2.0 over stdio / HTTP+SSE |
| **会话模型** | 通常无状态（REST）或流式（gRPC stream） | 有状态会话：initialize → 能力协商 → 多轮调用 |
| **类型系统** | OpenAPI / GraphQL Schema / Protobuf | JSON Schema（工具参数）+ URI 模板（资源） |
| **核心抽象** | Endpoint / Query / Method | Tool / Resource / Prompt |
| **安全模型** | Token / API Key / OAuth | 继承传输层认证 + human-in-the-loop 确认 |

## MCP 协议架构

```
┌─────────────────────────────────────────┐
│             MCP Client (AI)             │
│  ┌─────────┐ ┌──────────┐ ┌──────────┐ │
│  │ Tool    │ │ Resource │ │ Prompt   │ │
│  │ Caller  │ │ Reader   │ │ Renderer │ │
│  └────┬────┘ └────┬─────┘ └────┬─────┘ │
│       └───────────┼────────────┘       │
│                   │ JSON-RPC 2.0       │
└───────────────────┼─────────────────────┘
                    │ stdio / HTTP+SSE
┌───────────────────┼─────────────────────┐
│                   │                     │
│  ┌────────────────▼───────────────────┐ │
│  │        Capability Registry         │ │
│  └──┬──────────┬──────────────┬───────┘ │
│     ▼          ▼              ▼         │
│  ┌──────┐  ┌──────────┐  ┌────────┐    │
│  │Tools │  │Resources │  │Prompts │    │
│  └──────┘  └──────────┘  └────────┘    │
│             MCP Server                  │
└─────────────────────────────────────────┘
```

### 生命周期

1. **Initialize** — 客户端连接 server，双方交换协议版本和支持的能力
2. **Discovery** — 客户端请求 `tools/list`、`resources/list`、`prompts/list`
3. **Invocation** — AI 根据对话上下文选择 tool 调用或 resource 读取
4. **Shutdown** — 会话结束，释放资源

## MCP 三大原语

### 1. Tool — 可执行动作

Tool 是 MCP 中最核心的概念，等价于 API 中的一个 endpoint，但 **由 AI 自主决定何时调用**。

```jsonc
// MCP Tool 定义
{
  "name": "query_database",
  "description": "Run a read-only SQL query against the analytics database",
  "inputSchema": {
    "type": "object",
    "properties": {
      "sql": { "type": "string", "description": "SQL query to execute" }
    },
    "required": ["sql"]
  }
}
```

对比 API 等价物：

```
POST /api/v1/query
Content-Type: application/json
Authorization: Bearer <token>

{ "sql": "SELECT * FROM users LIMIT 10" }
```

关键区别：API 版本需要开发者写代码来调用；MCP 版本由 AI 看到 tool 描述后自主决定调用。

### 2. Resource — 可读数据

Resource 通过 URI 暴露数据，AI 可以按需浏览和读取。

```
resource://database/schema/users      → 返回 users 表结构
resource://docs/api-guide             → 返回 API 指南文档
```

对比 API：类似 `GET /schema/users`，但 MCP resource 支持 **URI 模板** 和 **订阅变更通知**。

### 3. Prompt — 预置交互模板

为特定场景预设的消息模板，传统 API 中没有对应概念。

```jsonc
{
  "name": "code_review",
  "description": "Review code for bugs and improvements",
  "arguments": [
    { "name": "language", "required": true },
    { "name": "code", "required": true }
  ]
}
```

## 五个本质区别

### 1. 主语不同 — 谁在做决策

- **API**：开发者是主语。人读文档 → 写代码 → 编译部署 → 代码运行时调用。
- **MCP**：AI 是主语。AI 连接 server → 读能力列表 → 理解用户意图 → 自主选择 tool → 组装参数 → 执行。

### 2. 集成模型不同 — N×M vs N+M

- **API**：每个客户端对每个服务都要写专门的集成代码。10 个客户端 × 10 个服务 = 100 套代码。
- **MCP**：协议统一，10 个客户端 + 10 个 server = 20 个实现即可全部互通。

### 3. 运行时行为不同 — 确定性 vs 自主决策

- **API** 调用是确定性的：同样的代码路径永远调用同一个 endpoint、传同样的参数结构。
- **MCP** 调用是自主决策的：AI 根据当前对话上下文选择 tool，不同场景下可能调用不同 tool 或传不同参数。

### 4. 发现机制不同 — 静态文档 vs 动态协商

- **API**：开发者离线阅读 Swagger / GraphQL Playground 等文档，提前了解接口结构。
- **MCP**：AI 在运行时通过 `tools/list` 动态获取可用能力，server 更新了 tool 定义后 AI 下次连接自动感知。

### 5. 安全模型不同 — 程序信任 vs Human-in-the-loop

- **API**：信任链是 token → 服务端权限检查。拿到 token 的代码可以自由调用。
- **MCP**：增加了 human-in-the-loop 层。AI 要调用敏感 tool（如写数据库、发邮件）时，需要用户显式批准。

## 选型指南

### 用 MCP 的场景

- AI 产品需要访问外部数据源或执行操作
- 希望 AI 能自主组合多步操作完成复杂任务
- 同一个工具需要被多种 AI 客户端使用
- 需要 human-in-the-loop 安全控制

### 用 API 的场景

- 前端/后端之间的服务通信
- 高频、低延迟的程序间调用
- 需要精确控制调用顺序和参数
- 非 AI 场景的系统集成

### 两者结合的场景

MCP server 内部通常封装了对传统 API 的调用：

```
用户 → AI (MCP Client) → MCP Server → 内部调用 REST API → 外部服务
```

MCP 不替代 API，而是在 AI 和 API 之间加了一层标准化的协议。

## MCP 实现指南

### 整体架构

一个 MCP server 的实现本质上就是：**用标准 SDK 把你的函数/数据包装成 Tool/Resource，然后通过 stdio 或 HTTP 暴露给 AI 客户端。**

```
你的业务逻辑（函数、API 调用、数据库查询）
        │
        ▼
┌───────────────────────┐
│   MCP SDK 包装层       │  ← 你写的代码，核心工作在这里
│  - 定义 Tool          │
│  - 定义 Resource      │
│  - 定义 Prompt        │
└──────────┬────────────┘
           │
     ┌─────┴──────┐
     │  Transport  │  ← SDK 内置，几乎不需要你写
     │ stdio / HTTP│
     └─────┬──────┘
           │
     AI 客户端连接
```

### 技术栈选择

| 语言 | SDK | 安装 | 适用场景 |
|------|-----|------|---------|
| TypeScript | `@modelcontextprotocol/sdk` | `npm i @modelcontextprotocol/sdk zod` | Web 服务封装、API 代理、通用工具 |
| Python | `fastmcp` | `pip install fastmcp` | 数据处理、ML、科学计算 |

### TypeScript 实现

#### 最小可运行 Server

```typescript
#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

// Create server instance
const server = new McpServer({
  name: "weather-server",
  version: "1.0.0",
});

// Register a tool
server.tool(
  "get_weather",
  "Get current weather for a city",
  { city: z.string().describe("City name, e.g. Beijing") },
  async ({ city }) => {
    const res = await fetch(`https://api.weather.example/v1?q=${city}`);
    const data = await res.json();
    return {
      content: [{ type: "text", text: JSON.stringify(data) }],
    };
  }
);

// Register a resource
server.resource(
  "supported-cities",
  "weather://cities",
  { description: "List of supported cities" },
  async () => ({
    contents: [{
      uri: "weather://cities",
      text: "Beijing, Shanghai, Tokyo, New York, London",
    }],
  })
);

// Start with stdio transport
const transport = new StdioServerTransport();
await server.connect(transport);
```

#### 项目初始化

```bash
mkdir my-mcp-server && cd my-mcp-server
npm init -y
npm install @modelcontextprotocol/sdk zod
npm install -D typescript tsx
```

`tsconfig.json`：

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "outDir": "dist",
    "strict": true
  }
}
```

`package.json` 中添加：

```json
{
  "type": "module",
  "bin": { "my-mcp-server": "dist/index.js" },
  "scripts": {
    "build": "tsc",
    "dev": "tsx src/index.ts"
  }
}
```

### Python 实现

#### 最小可运行 Server

```python
from fastmcp import FastMCP

mcp = FastMCP("weather-server")

@mcp.tool
def get_weather(city: str) -> str:
    """Get current weather for a city."""
    import urllib.request, json
    url = f"https://api.weather.example/v1?q={city}"
    data = json.loads(urllib.request.urlopen(url).read())
    return json.dumps(data)

@mcp.resource("weather://cities")
def list_cities() -> str:
    """List of supported cities."""
    return "Beijing, Shanghai, Tokyo, New York, London"

if __name__ == "__main__":
    mcp.run()
```

#### 项目初始化

```bash
mkdir my-mcp-server && cd my-mcp-server
python -m venv .venv && source .venv/bin/activate
pip install fastmcp
```

Python SDK 的 `@mcp.tool` 装饰器自动从函数签名中提取：
- **函数名** → tool name
- **docstring** → tool description
- **类型注解** → JSON Schema 参数定义

### 两种传输方式

#### stdio（本地工具推荐）

AI 客户端作为父进程 spawn MCP server 子进程，通过 stdin/stdout 交换 JSON-RPC 消息。

```
AI Client (父进程)
    │
    ├─ spawn ──→ MCP Server (子进程)
    │              stdin  ← JSON-RPC request
    │              stdout → JSON-RPC response
    │              stderr → 日志（不影响协议）
    │
    └─ 会话结束时 kill 子进程
```

特点：
- 零网络配置，即开即用
- 进程隔离，安全性好
- 每个客户端连接对应一个进程
- 适合本地工具：文件系统、Git、数据库、CLI 封装

#### Streamable HTTP（远程服务推荐）

MCP server 作为 HTTP 服务运行，客户端通过 HTTP POST 发送请求，通过 SSE 接收流式响应。

```
AI Client ──HTTP POST──→  MCP Server (:3000/mcp)
           ←───SSE────    (长连接流式返回)
```

TypeScript 示例（Express 中间件）：

```typescript
import express from "express";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";

const app = express();
const server = new McpServer({ name: "remote-server", version: "1.0.0" });

// ... register tools ...

app.post("/mcp", async (req, res) => {
  const transport = new StreamableHTTPServerTransport("/mcp");
  await server.connect(transport);
  await transport.handleRequest(req, res);
});

app.listen(3000);
```

特点：
- 支持远程部署和多用户
- 可以加认证、负载均衡
- 适合云服务、SaaS 工具

### 客户端接入配置

#### Claude Desktop

配置文件位置：
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`
- Linux: `~/.config/Claude/claude_desktop_config.json`

stdio server 配置：

```json
{
  "mcpServers": {
    "weather": {
      "command": "node",
      "args": ["/path/to/weather-server/dist/index.js"],
      "env": {
        "WEATHER_API_KEY": "your-key"
      }
    }
  }
}
```

修改后需**完全重启** Claude Desktop。

#### Cursor

配置文件位置：
- 项目级: `.cursor/mcp.json`（项目根目录）
- 全局: `~/.cursor/mcp.json`

```json
{
  "mcpServers": {
    "weather": {
      "command": "node",
      "args": ["/path/to/weather-server/dist/index.js"],
      "env": {
        "WEATHER_API_KEY": "your-key"
      }
    }
  }
}
```

Cursor 支持热重载，无需重启。

#### 远程 HTTP Server 配置

```json
{
  "mcpServers": {
    "remote-weather": {
      "url": "https://weather-mcp.example.com/mcp",
      "headers": {
        "Authorization": "Bearer your-token"
      }
    }
  }
}
```

### 实现四步走

```
第 1 步          第 2 步            第 3 步          第 4 步
选 SDK           定义能力            选传输           注册到客户端
┌──────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐
│ TS   │      │ Tool     │      │ stdio    │      │ Claude   │
│  or  │ ──→  │ Resource │ ──→  │   or     │ ──→  │ Cursor   │
│ Py   │      │ Prompt   │      │ HTTP     │      │ 其他     │
└──────┘      └──────────┘      └──────────┘      └──────────┘
```

1. **选 SDK** — TypeScript（npm）或 Python（pip），安装依赖
2. **定义能力** — 写业务函数，用 `server.tool()` 或 `@mcp.tool` 注册，关键是写好 description 和参数 schema，这决定了 AI 能否正确理解和调用
3. **选传输** — 本地工具用 stdio（默认），远程服务用 Streamable HTTP
4. **注册到客户端** — 在 AI 客户端配置 JSON 中添加 server 条目

### 实际案例：把现有 REST API 包装成 MCP Server

假设你有一个内部 REST API `https://internal.api/users`，想让 AI 能查询用户信息：

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "user-api", version: "1.0.0" });
const API_BASE = process.env.API_BASE || "https://internal.api";

// Wrap REST GET /users/:id as MCP tool
server.tool(
  "get_user",
  "Look up a user by ID, returns name/email/role",
  { user_id: z.string().describe("User ID") },
  async ({ user_id }) => {
    const res = await fetch(`${API_BASE}/users/${user_id}`, {
      headers: { Authorization: `Bearer ${process.env.API_TOKEN}` },
    });
    if (!res.ok) {
      return { content: [{ type: "text", text: `Error: ${res.status}` }], isError: true };
    }
    return { content: [{ type: "text", text: JSON.stringify(await res.json()) }] };
  }
);

// Wrap REST GET /users?q=keyword as MCP tool
server.tool(
  "search_users",
  "Search users by name or email keyword",
  { keyword: z.string().describe("Search keyword") },
  async ({ keyword }) => {
    const res = await fetch(`${API_BASE}/users?q=${encodeURIComponent(keyword)}`, {
      headers: { Authorization: `Bearer ${process.env.API_TOKEN}` },
    });
    return { content: [{ type: "text", text: JSON.stringify(await res.json()) }] };
  }
);

await server.connect(new StdioServerTransport());
```

这个例子展示了 MCP 和 API 的关系：**MCP server 内部调 REST API，对 AI 暴露语义化的 tool 接口**。

## 常见误区

| 误区 | 纠正 |
|------|------|
| MCP 会替代 API | 不会。MCP server 内部通常还是调 API，两者是不同层次 |
| MCP 就是"给 AI 用的 API" | 不准确。MCP 多了能力发现、会话管理、human-in-the-loop 等完整协议机制 |
| 有了 Function Calling 就不需要 MCP | Function Calling 是 LLM 层面的调用能力，MCP 是连接层的标准协议，两者互补 |
| MCP 只能用 stdio 通信 | MCP 支持 stdio 和 HTTP+SSE 两种传输方式 |
| MCP 只有 Tool 一个概念 | MCP 有 Tool、Resource、Prompt 三大原语 |

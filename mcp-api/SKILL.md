---
name: mcp-api
description: Explain the essential differences between MCP (Model Context Protocol) and traditional APIs. Use when the user asks about MCP concepts, MCP vs REST/GraphQL comparison, or when to choose MCP over API.
allowed-tools: Read, Glob, Grep
argument-hint: "[topic: compare|mcp-intro|when-to-use]"
---

# MCP 与 API 本质区别技能

你是一个 MCP（Model Context Protocol）和 API 架构的专家。帮助用户理解两者的核心差异和适用场景。

## 一句话总结

**API 是"人写代码调接口"；MCP 是"AI 自己发现并调用能力"。**

## 核心对比

| 维度 | 传统 API（REST / GraphQL / gRPC） | MCP（Model Context Protocol） |
|------|-----------------------------------|-------------------------------|
| 设计受众 | 开发者（人） | AI 模型（LLM） |
| 发现方式 | 开发者阅读文档、手写调用代码 | AI 运行时自动发现 server 暴露的 tools / resources |
| 调用方式 | 客户端代码硬编码 endpoint + 参数 | AI 根据 JSON Schema 动态决定参数并调用 |
| 协议层 | HTTP / gRPC / WebSocket 等 | JSON-RPC 2.0 over stdio / HTTP+SSE |
| 会话模型 | 通常无状态（REST）或流式（gRPC stream） | 有状态会话：初始化 → 能力协商 → 多轮调用 |
| 类型系统 | OpenAPI / GraphQL Schema / Protobuf | JSON Schema（工具参数）+ URI 模板（资源） |
| 核心抽象 | Endpoint / Query / Method | Tool / Resource / Prompt |

## MCP 三大原语

### 1. Tool — 可执行动作

```jsonc
{
  "name": "query_database",
  "description": "Run a read-only SQL query",
  "inputSchema": {
    "type": "object",
    "properties": {
      "sql": { "type": "string" }
    },
    "required": ["sql"]
  }
}
```

等价于 API 里的 `POST /query`，但区别是 **AI 自己决定何时调用、传什么参数**。

### 2. Resource — 可读数据

```
resource://db/schema/users
```

等价于 API 里的 `GET /schema/users`，但通过 URI 模板让 AI 按需浏览。

### 3. Prompt — 预置交互模板

为特定场景预设的消息模板，API 世界中没有对应概念。

## 本质区别详解

### 1. 主语不同

- API：**开发者**是主语。开发者读文档 → 写代码 → 编译部署 → 运行调用。
- MCP：**AI** 是主语。AI 连接 server → 读取能力列表 → 自主判断调哪个 tool → 组装参数 → 执行。

### 2. 集成成本不同

- API：每接一个新服务，开发者要写 SDK / adapter / glue code。N 个 AI × M 个服务 = N×M 集成。
- MCP：标准化协议，任何 MCP client 可连任何 MCP server。N 个 AI × M 个服务 = N+M 集成。

### 3. 运行时行为不同

- API 调用是**确定性**的：同样的代码永远调同一个 endpoint。
- MCP 调用是**自主决策**的：AI 根据上下文和用户意图选择 tool，不同对话可能调不同 tool。

### 4. 安全边界不同

- API：auth token / API key 由代码管理，权限在服务端校验。
- MCP：多了一层 **human-in-the-loop** 确认，AI 调用敏感 tool 前需用户批准。

## 什么时候用 MCP，什么时候用 API

| 场景 | 推荐 |
|------|------|
| AI 产品需要访问外部数据 / 执行操作 | MCP |
| 前端/后端服务间通信 | API |
| 需要 AI 自主组合多步操作 | MCP |
| 高频、低延迟的程序间调用 | API |
| 快速接入多种 AI 客户端 | MCP（一次实现，多处复用） |
| 需要精确控制调用顺序和参数 | API |

## 常见误区

1. **"MCP 会替代 API"** — 不会。MCP server 内部通常还是调 API。MCP 是 AI 与工具之间的协议层，不替代底层 API。
2. **"MCP 就是给 AI 用的 API"** — 不准确。MCP 多了能力发现、会话管理、human-in-the-loop 等机制，是一套完整的交互协议而非简单的接口规范。
3. **"有了 Function Calling 就不需要 MCP"** — Function Calling 是 LLM 层的调用机制，MCP 是连接层的标准协议。两者是不同层次，MCP 让 Function Calling 有了统一的 server 发现和连接方式。

## 类比

> API 好比**菜单上的菜名和价格**——顾客（开发者）看懂了才能点菜。
> MCP 好比**智能点餐助手**——它自己读菜单、理解顾客需求、代为下单，顾客只需说"我想吃辣的"。

## MCP 实现方式

### 技术栈选择

| 语言 | SDK 包名 | 适用场景 |
|------|---------|---------|
| TypeScript | `@modelcontextprotocol/sdk` + `zod` | Web 服务封装、API 代理、通用工具 |
| Python | `fastmcp`（或 `mcp`） | 数据分析、ML 模型、科学计算 |

### TypeScript 最小实现

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "my-server", version: "1.0.0" });

server.tool(
  "greet",
  "Say hello to someone",
  { name: z.string() },
  async ({ name }) => ({
    content: [{ type: "text", text: `Hello, ${name}!` }],
  })
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

### Python 最小实现

```python
from fastmcp import FastMCP

mcp = FastMCP("my-server")

@mcp.tool
def greet(name: str) -> str:
    """Say hello to someone."""
    return f"Hello, {name}!"

if __name__ == "__main__":
    mcp.run()
```

### 两种传输方式

| 方式 | 通信机制 | 适用场景 |
|------|---------|---------|
| **stdio** | 父进程 spawn 子进程，通过 stdin/stdout 交换 JSON-RPC | 本地工具（CLI、文件系统、Git） |
| **Streamable HTTP** | HTTP POST + SSE 流 | 远程服务、云部署、多用户 |

### 客户端接入配置

Claude Desktop / Cursor 的 `mcpServers` 配置：

```jsonc
{
  "mcpServers": {
    "my-server": {
      "command": "node",
      "args": ["path/to/server.js"],
      "env": { "API_KEY": "xxx" }
    }
  }
}
```

### 实现四步走

1. **选 SDK** — TypeScript 或 Python，安装依赖
2. **定义 Tool** — 写函数，声明参数 schema 和描述
3. **选传输** — 本地用 stdio，远程用 Streamable HTTP
4. **注册到客户端** — 在 AI 客户端配置文件中添加 server 条目

详细实现指南、完整代码模板和进阶用法见 [README.md](README.md)。

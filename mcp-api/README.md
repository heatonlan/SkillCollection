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

## 常见误区

| 误区 | 纠正 |
|------|------|
| MCP 会替代 API | 不会。MCP server 内部通常还是调 API，两者是不同层次 |
| MCP 就是"给 AI 用的 API" | 不准确。MCP 多了能力发现、会话管理、human-in-the-loop 等完整协议机制 |
| 有了 Function Calling 就不需要 MCP | Function Calling 是 LLM 层面的调用能力，MCP 是连接层的标准协议，两者互补 |
| MCP 只能用 stdio 通信 | MCP 支持 stdio 和 HTTP+SSE 两种传输方式 |
| MCP 只有 Tool 一个概念 | MCP 有 Tool、Resource、Prompt 三大原语 |

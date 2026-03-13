---
name: cloudflare-tunnel
description: Set up Cloudflare Tunnel to expose local services to the public internet via subdomains. Use when the user wants to expose localhost services, configure cloudflared, add ingress rules, or troubleshoot tunnel issues.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: "[action: setup|add-service|troubleshoot]"
---

# Cloudflare Tunnel 配置技能

你是一个 Cloudflare Tunnel 配置专家。根据用户的需求，帮助完成 tunnel 的安装、创建、DNS 路由配置和 ingress 规则管理。

## 核心知识

- cloudflared 通过 outbound QUIC/HTTP2 连接到 Cloudflare 边缘网络，无需 inbound port
- 一个 Tunnel 可承载多个子域名（通过 ingress rules 的 virtual host routing）
- ingress 按顺序匹配，最后一条必须是无 hostname 的兜底规则（通常 `service: http_status:404`）
- 凭据文件：`~/.cloudflared/<TUNNEL_ID>.json`（敏感，不可提交 Git）
- 配置文件：`~/.cloudflared/config.yml`

## 操作流程

### 新建 Tunnel

1. 安装 cloudflared（Windows: 下载 exe 到 `C:\cloudflared\`；Linux/macOS: 包管理器）
2. `cloudflared tunnel login` — 浏览器授权，生成 `cert.pem`
3. `cloudflared tunnel create <NAME>` — 创建 tunnel，生成凭据 JSON
4. `cloudflared tunnel route dns <NAME> <SUBDOMAIN>` — 创建 DNS CNAME
5. 编写 `~/.cloudflared/config.yml` 配置 ingress 规则
6. `pm2 start cloudflared --name cloudflared -- tunnel run <NAME>` 守护运行

### 添加服务到已有 Tunnel

1. 读取现有 `~/.cloudflared/config.yml`
2. 在 ingress 的兜底规则之前插入新的 hostname → service 映射
3. `cloudflared tunnel route dns <NAME> <NEW_SUBDOMAIN>` 添加 DNS
4. `pm2 restart cloudflared`

### 故障排查

| 症状 | 原因 | 解决 |
|------|------|------|
| `ERR No tunnel credentials found` | 缺少凭据 JSON | 复制凭据或重新 `tunnel create` |
| `ERR Unable to reach the origin service` | 本地服务未启动或端口错误 | 检查 config.yml 端口 |
| `ERR certificate error` | cert.pem 过期 | 重新 `tunnel login` |
| 网页 502 | 本地服务异常 | 检查本地服务日志 |

## config.yml 模板

```yaml
tunnel: <TUNNEL_ID>
credentials-file: ~/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: app.example.com
    service: http://127.0.0.1:3000
  # 兜底规则必须在最后
  - service: http_status:404
```

## 注意事项

- `cert.pem` 和 `<TUNNEL_ID>.json` 是敏感文件，绝不提交 Git
- 同一 Tunnel 同一时间只能在一台机器上运行
- Cloudflare Tunnel 自带 HTTPS，无需额外证书
- 免费版 Cloudflare 即可使用

详细安装步骤和跨机器复用说明见 [README.md](README.md)。

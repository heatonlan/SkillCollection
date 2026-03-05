# Cloudflare Tunnel - 本地服务公网暴露

通过 Cloudflare Tunnel（`cloudflared`）将本地 Web 服务安全地暴露到公网，无需公网 IP、无需端口转发。

## 适用场景

- 本地开发的 Web 应用需要公网访问（远程协作、手机调试等）
- 多个本地服务通过不同子域名暴露
- 配合 PM2 实现进程守护和自动重启

## 前置条件

- 一个 Cloudflare 账号
- 一个已托管到 Cloudflare 的域名（DNS 由 Cloudflare 管理）
- Windows / Linux / macOS 均可

---

## 第一步：安装 cloudflared

### Windows

从 [GitHub Releases](https://github.com/cloudflare/cloudflared/releases) 下载 `cloudflared-windows-amd64.exe`，放到固定路径：

```
C:\cloudflared\cloudflared.exe
```

### Linux / macOS

```bash
# Debian / Ubuntu
curl -fsSL https://pkg.cloudflare.com/cloudflared-linux-amd64.deb -o cloudflared.deb
sudo dpkg -i cloudflared.deb

# macOS
brew install cloudflared
```

验证安装：

```bash
cloudflared --version
```

---

## 第二步：登录 Cloudflare

```bash
cloudflared tunnel login
```

会打开浏览器让你授权。授权后会在 `~/.cloudflared/` 下生成 `cert.pem` 证书文件。

---

## 第三步：创建 Tunnel

```bash
cloudflared tunnel create <TUNNEL_NAME>
```

例如：

```bash
cloudflared tunnel create web-terminal
```

成功后会输出 Tunnel ID（UUID 格式），并在 `~/.cloudflared/` 下生成对应的 `<TUNNEL_ID>.json` 凭据文件。

---

## 第四步：配置 DNS 路由

将子域名指向 Tunnel：

```bash
cloudflared tunnel route dns <TUNNEL_NAME> <SUBDOMAIN>
```

例如，将 `work.example.com` 指向 tunnel：

```bash
cloudflared tunnel route dns web-terminal work.example.com
```

如果有多个服务，可以为同一个 Tunnel 添加多条 DNS 路由：

```bash
cloudflared tunnel route dns web-terminal desk.example.com
cloudflared tunnel route dns web-terminal file.example.com
```

> 这会自动在 Cloudflare DNS 中创建 CNAME 记录，无需手动操作 DNS 面板。

---

## 第五步：编写配置文件

创建 `~/.cloudflared/config.yml`：

```yaml
tunnel: <TUNNEL_ID>
credentials-file: ~/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: work.example.com
    service: http://127.0.0.1:3000
  - hostname: desk.example.com
    service: http://127.0.0.1:3001
  - hostname: file.example.com
    service: http://127.0.0.1:3003
  - service: http_status:404
```

**说明：**
- `ingress` 按顺序匹配，最后一条必须是无 hostname 的兜底规则
- 每条规则将一个子域名映射到本地服务端口
- 一个 Tunnel 可以映射多个子域名

---

## 第六步：启动 Tunnel

### 手动启动

```bash
cloudflared tunnel run <TUNNEL_NAME>
```

### 使用 PM2 守护运行（推荐）

```bash
pm2 start cloudflared -- tunnel run <TUNNEL_NAME>
```

多服务配合 PM2 的完整启动示例：

```bash
# 启动本地服务
pm2 start server.js --name web-terminal
pm2 start server.js --name desk-viewer --cwd ./desk-viewer

# 启动 tunnel（一个 tunnel 进程承载所有 ingress 规则）
pm2 start cloudflared --name cloudflared -- tunnel run web-terminal

# 保存进程列表（开机自启）
pm2 save
```

---

## 常用命令速查

| 操作 | 命令 |
|------|------|
| 查看所有 Tunnel | `cloudflared tunnel list` |
| 查看 Tunnel 详情 | `cloudflared tunnel info <NAME>` |
| 删除 Tunnel | `cloudflared tunnel delete <NAME>` |
| 查看 DNS 路由 | Cloudflare Dashboard > DNS |
| 查看运行日志 | `pm2 logs cloudflared` |
| 重启 Tunnel | `pm2 restart cloudflared` |

---

## 目录结构参考

```
~/.cloudflared/
  cert.pem                  # 登录凭据（tunnel login 生成）
  config.yml                # ingress 配置
  <TUNNEL_ID>.json          # tunnel 凭据（tunnel create 生成）
```

---

## 在其他机器上复用已有 Tunnel

如果已经在一台机器上创建好了 Tunnel，想在另一台机器上运行同一个 Tunnel（或迁移），不需要重新创建，只需复制凭证文件。

### 需要复制的文件

从源机器的 `~/.cloudflared/` 复制到目标机器的相同目录：

| 文件 | 作用 | 是否必须 |
|------|------|----------|
| `<TUNNEL_ID>.json` | Tunnel 凭据，用于认证 | 必须 |
| `config.yml` | ingress 路由配置 | 必须（也可重新编写） |
| `cert.pem` | 账号登录凭据，用于管理操作 | 仅管理时需要 |

> `cert.pem` 只在执行管理操作（创建/删除 tunnel、配置 DNS 路由）时需要。如果只是运行已有 tunnel，只需 `<TUNNEL_ID>.json` 和 `config.yml`。

### 步骤

1. **安装 cloudflared**（见第一步）

2. **复制凭证文件**到目标机器的 `~/.cloudflared/` 目录：
   ```bash
   # 在目标机器上创建目录
   mkdir -p ~/.cloudflared

   # 从源机器复制（通过 scp、U盘、或其他方式）
   scp source-machine:~/.cloudflared/<TUNNEL_ID>.json ~/.cloudflared/
   scp source-machine:~/.cloudflared/config.yml ~/.cloudflared/
   ```

3. **修改 config.yml** 中的端口映射（如果目标机器的服务端口不同）

4. **启动 Tunnel**：
   ```bash
   cloudflared tunnel run <TUNNEL_NAME>
   ```

### 注意

- 同一个 Tunnel 同一时间只能在一台机器上运行
- 如果需要多台机器同时暴露服务，应为每台机器创建独立的 Tunnel
- 凭证文件传输时注意安全，避免通过不安全的渠道（如明文邮件、公共聊天）发送

---

## 故障排查

| 症状 | 原因 | 解决 |
|------|------|------|
| `ERR No tunnel credentials found` | 缺少 `<TUNNEL_ID>.json` | 从源机器复制凭据文件，或重新 `tunnel create` |
| `ERR Unable to reach the origin service` | 本地服务未启动或端口不对 | 检查 `config.yml` 中的端口是否与实际服务一致 |
| `ERR certificate error` | `cert.pem` 过期或缺失 | 重新执行 `cloudflared tunnel login` |
| DNS 不生效 | CNAME 记录未创建 | 执行 `cloudflared tunnel route dns` 或在 Dashboard 手动添加 |
| Tunnel 启动但网页 502 | 本地服务返回错误 | 检查本地服务日志，确认服务可在 localhost 访问 |

---

## 注意事项

1. `cert.pem` 和 `<TUNNEL_ID>.json` 是敏感文件，不要提交到 Git
2. 一个 Tunnel 可以承载多个子域名，不需要为每个服务创建单独的 Tunnel
3. Cloudflare Tunnel 自带 HTTPS，无需额外配置证书
4. 如果本地服务重启了端口变化，只需修改 `config.yml` 并重启 cloudflared
5. 免费版 Cloudflare 即可使用 Tunnel 功能

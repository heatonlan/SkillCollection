#!/usr/bin/env bash
# Cloudflare Tunnel 一键配置脚本
# 用法: ./setup.sh <TUNNEL_NAME> <DOMAIN> <LOCAL_PORT>
# 示例: ./setup.sh web-terminal work.example.com 3000

set -e

TUNNEL_NAME="${1:?用法: $0 <TUNNEL_NAME> <DOMAIN> <LOCAL_PORT>}"
DOMAIN="${2:?请指定域名，例如 work.example.com}"
LOCAL_PORT="${3:?请指定本地端口，例如 3000}"

CONFIG_DIR="$HOME/.cloudflared"
CONFIG_FILE="$CONFIG_DIR/config.yml"

echo "=== Cloudflare Tunnel Setup ==="
echo "  Tunnel:  $TUNNEL_NAME"
echo "  Domain:  $DOMAIN"
echo "  Port:    $LOCAL_PORT"
echo ""

# Step 1: Login
if [ ! -f "$CONFIG_DIR/cert.pem" ]; then
    echo "[1/4] 登录 Cloudflare（将打开浏览器）..."
    cloudflared tunnel login
else
    echo "[1/4] 已登录，跳过"
fi

# Step 2: Create tunnel
echo "[2/4] 创建 Tunnel: $TUNNEL_NAME ..."
cloudflared tunnel create "$TUNNEL_NAME" 2>/dev/null || echo "  Tunnel 可能已存在，继续"

# Get tunnel ID
TUNNEL_ID=$(cloudflared tunnel list -o json | grep -o "\"id\":\"[^\"]*\"" | head -1 | cut -d'"' -f4)
if [ -z "$TUNNEL_ID" ]; then
    echo "错误: 无法获取 Tunnel ID"
    exit 1
fi
echo "  Tunnel ID: $TUNNEL_ID"

# Step 3: Route DNS
echo "[3/4] 配置 DNS: $DOMAIN -> $TUNNEL_NAME ..."
cloudflared tunnel route dns "$TUNNEL_NAME" "$DOMAIN" 2>/dev/null || echo "  DNS 路由可能已存在，继续"

# Step 4: Write config
echo "[4/4] 写入配置文件: $CONFIG_FILE ..."

if [ -f "$CONFIG_FILE" ]; then
    echo "  配置文件已存在，请手动添加 ingress 规则:"
    echo ""
    echo "  - hostname: $DOMAIN"
    echo "    service: http://127.0.0.1:$LOCAL_PORT"
    echo ""
else
    cat > "$CONFIG_FILE" <<EOF
tunnel: $TUNNEL_ID
credentials-file: $CONFIG_DIR/$TUNNEL_ID.json

ingress:
  - hostname: $DOMAIN
    service: http://127.0.0.1:$LOCAL_PORT
  - service: http_status:404
EOF
    echo "  配置已写入"
fi

echo ""
echo "=== 配置完成 ==="
echo "启动命令: cloudflared tunnel run $TUNNEL_NAME"
echo "PM2 守护: pm2 start cloudflared -- tunnel run $TUNNEL_NAME"

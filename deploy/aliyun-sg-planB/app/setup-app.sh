#!/usr/bin/env bash
# 应用机一键初始化：Docker + sub2api(standalone) + Caddy(TLS)
# 在【应用机】上执行：sudo bash setup-app.sh your-domain.com
set -euo pipefail

DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then
  echo "用法: sudo bash setup-app.sh your-domain.com"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> [1/5] 安装 Docker"
if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io docker-compose-v2
  sudo systemctl enable --now docker
fi

echo "==> [2/5] 配置镜像加速"
if [ ! -f /etc/docker/daemon.json ]; then
  sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1ms.run",
    "https://docker.mirrors.ustc.edu.cn"
  ]
}
EOF
  sudo systemctl restart docker
fi

echo "==> [3/5] 检查 .env"
if [ ! -f .env ]; then
  cp app.env .env
  echo "    已生成 .env，请先编辑填入 DATABASE_HOST / REDIS_HOST / 密码等" >&2
  echo "    命令：nano $SCRIPT_DIR/.env" >&2
  exit 1
fi

echo "==> [4/5] 启动 sub2api（standalone，连接数据库机）"
REPO_COMPOSE="$SCRIPT_DIR/../docker-compose.standalone.yml"
if [ ! -f "$REPO_COMPOSE" ]; then
  echo "    未找到 docker-compose.standalone.yml，请把仓库 deploy/ 目录整体拷到机器上" >&2
  exit 1
fi
sudo docker pull weishaw/sub2api:latest
sudo docker compose -f "$REPO_COMPOSE" --env-file .env up -d

echo "==> [5/5] 启动 Caddy（自动签发 Let's Encrypt 证书）"
sudo mkdir -p /var/log/caddy
sudo docker rm -f caddy 2>/dev/null || true
sudo docker run -d --name caddy \
  --restart unless-stopped \
  --network host \
  -e DOMAIN="$DOMAIN" \
  -v "$SCRIPT_DIR/Caddyfile:/etc/caddy/Caddyfile:ro" \
  -v caddy_data:/data \
  -v caddy_config:/config \
  -v /var/log/caddy:/var/log/caddy \
  caddy:2-alpine

echo "==> 等待启动..."
sleep 15
echo "--- 健康检查 ---"
curl -sk "https://$DOMAIN/health" || curl -s http://localhost/health || echo "还在启动，稍等"
echo ""
echo "=========================================================="
echo "应用机初始化完成。"
echo "前置条件确认："
echo "  1. 域名 $DOMAIN 的 A 记录已指向本机 EIP"
echo "  2. 安全组已放行 80/443（Caddy 自动 TLS 需要 80 验证）"
echo "  3. 8080 不必对公网开放（BIND_HOST=127.0.0.1，仅 Caddy 本地访问）"
echo "访问：https://$DOMAIN"
echo "=========================================================="

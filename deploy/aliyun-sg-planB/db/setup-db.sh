#!/usr/bin/env bash
# 数据库机一键初始化：安装 Docker 并启动 PostgreSQL 18 + Redis 8
# 在【数据库机】上以普通用户执行：bash setup-db.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> [1/4] 安装 Docker"
if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io docker-compose-v2
  sudo systemctl enable --now docker
  sudo usermod -aG docker "$USER"
  echo "    Docker 已装，需重新登录使 docker 组生效（或后续用 sudo docker）"
fi

echo "==> [2/4] 配置镜像加速（国内拉 Docker Hub 不通时需要）"
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

echo "==> [3/4] 检查 .env"
if [ ! -f .env ]; then
  cp .env.db.example .env
  echo "    已生成 .env，请先编辑填入 PG_PASSWORD / REDIS_PASSWORD 后重跑本脚本" >&2
  echo "    命令：nano $SCRIPT_DIR/.env" >&2
  exit 1
fi

echo "==> [4/4] 启动 PG + Redis"
sudo docker compose -f docker-compose.db.yml up -d

echo "==> 等待健康检查..."
sleep 12
sudo docker compose -f docker-compose.db.yml ps

echo ""
echo "=========================================================="
echo "数据库机初始化完成。"
echo "下一步："
echo "  1. 阿里云控制台查看本机内网 IP（如 10.0.0.x），应用机用它连接"
echo "  2. 安全组【仅】允许应用机内网 IP 访问 5432/6379，禁止 0.0.0.0/0"
echo "  3. 配置定时备份：crontab -e 添加 pg-backup-to-oss.sh"
echo "=========================================================="

# Sub2API 阿里云部署手册

> 适用规模：~100 人运营，两台 ECS 分离部署（应用机 + 数据库机）。
> 本文档基于项目 `deploy/` 目录和 `deploy/aliyun-sg-planB/` 目录的实际文件提炼，可直接在其他阿里云账号下复现。

---

## 1. 架构总览

```
┌──────────────────────────────────────────────────────────┐
│  阿里云 VPC（同一可用区）                                  │
│                                                          │
│  ┌─────────────┐  内网互通（免费）  ┌─────────────────┐  │
│  │   应用机     │ ◄──────────────► │    数据库机       │  │
│  │ g8a.large   │                  │ g8a.large        │  │
│  │ 2C4G        │  :5432 (PG)      │ 2C4G + 100G PL1  │  │
│  │ + EIP       │  :6379 (Redis)   │ 数据盘            │  │
│  ─────────────┘                  └─────────────────┘  │
│       │                                                │
│       ▼                                                │
│  Caddy (443) ──► sub2api (127.0.0.1:8080)              │
│  Let's Encrypt TLS                                      │
──────────────────────────────────────────────────────────┘
```

| 机器 | 规格 | 运行服务 | 公网 |
|---|---|---|---|
| **应用机** | ecs.g8a.large (2C4G) | sub2api + Caddy | EIP + 80/443 |
| **数据库机** | ecs.g8a.large (2C4G) + 100GB PL1 数据盘 | PostgreSQL 18 + Redis 8（Docker 自建） | 无公网，仅内网 |

---

## 2. 阿里云控制台准备

### 2.1 VPC 与 ECS

1. 在目标区域创建 VPC + 交换机（两台 ECS 必须在 **同一 VPC、同一可用区**，内网互通免费）。
2. 购买 2 台 ECS：
   - 操作系统：**Ubuntu 22.04**
   - 规格：**ecs.g8a.large**（2 vCPU / 4 GiB）
   - 付费方式：包年包月（成本更低）
   - 系统盘：40GB ESSD
3. 数据库机额外挂载 **ESSD PL1 100GB 数据盘**（用于 PG 数据存储）。

### 2.2 网络与安全组

| 安全组规则 | 应用机 | 数据库机 |
|---|---|---|
| SSH (22) | 仅你的 IP | 仅你的 IP |
| HTTP (80) | 0.0.0.0/0 | — |
| HTTPS (443) | 0.0.0.0/0 | — |
| PostgreSQL (5432) | — | 仅应用机**内网 IP**（非 0.0.0.0/0） |
| Redis (6379) | — | 仅应用机**内网 IP**（非 0.0.0.0/0） |

> **重要**：数据库机的 5432/6379 端口 **绝对不要**对 0.0.0.0/0 开放。即使密码泄露，外网也无法连接。

### 2.3 EIP 与域名

- 申请 EIP（按使用流量计费，峰值 20Mbps），绑定到**应用机**。
- 域名 A 记录指向应用机 EIP 的公网 IP。

### 2.4 OSS 备份（可选但推荐）

1. 在同区域创建 OSS Bucket。
2. 创建 RAM 子账号，**仅授该 Bucket 的读写权限**，保存 AK/SK。
3. 用于每日 PG 自动备份（见第 5 节）。

---

## 3. 数据库机部署

### 3.1 文件准备

将仓库中 `deploy/aliyun-sg-planB/db/` 目录下的文件上传到数据库机：

```
db/
├── docker-compose.db.yml   # PG18 + Redis8 编排
├── .env.db.example         # 环境变量模板
├── setup-db.sh             # 一键初始化脚本
└── pg-backup-to-oss.sh     # 每日备份脚本
```

### 3.2 配置环境变量

```bash
cd db
cp .env.db.example .env
nano .env
```

需要修改的项：

| 变量 | 说明 | 示例 |
|---|---|---|
| `PG_PASSWORD` | PostgreSQL 密码（强密码） | `a1b2c3d4e5f6g7h8` |
| `REDIS_PASSWORD` | Redis 密码（强密码） | `x9y8z7w6v5u4t3s2` |

> 生成强密码：`openssl rand -hex 16`

### 3.3 一键初始化

```bash
bash setup-db.sh
```

脚本自动完成：
1. 安装 Docker（如未安装）
2. 配置 Docker Hub 镜像加速（国内拉取需要）
3. 检查 `.env` 是否已填写
4. 启动 PostgreSQL 18 + Redis 8 容器

### 3.4 记录内网 IP

在阿里云控制台查看数据库机的**内网 IP**（如 `10.0.0.10`），应用机需要用它来连接。

### 3.5 PG 参数说明（已针对 2C4G 调优）

| 参数 | 值 | 说明 |
|---|---|---|
| `max_connections` | 100 | 最大连接数 |
| `shared_buffers` | 1GB | 共享缓存（4GB 内存的 25%） |
| `effective_cache_size` | 2GB | 查询规划器假设的缓存大小 |
| `maintenance_work_mem` | 128MB | 维护操作内存 |
| `work_mem` | 8MB | 排序/哈希操作内存 |
| `log_min_duration_statement` | 1000ms | 记录慢查询（≥1s） |

### 3.6 配置定时备份

```bash
# 编辑备份脚本，修改 OSS 配置
nano pg-backup-to-oss.sh
# 修改 OSS_BUCKET 和 OSS_ENDPOINT

# 配置 ossutil
sudo chmod +x pg-backup-to-oss.sh
ossutil config -e oss-ap-southeast-1.aliyuncs.com   # 填入 RAM AK/SK

# 测试一次
sudo ./pg-backup-to-oss.sh

# 添加 cron 定时任务（每天凌晨 3 点备份）
sudo crontab -e
# 添加：
# 0 3 * * * /path/to/pg-backup-to-oss.sh >> /var/log/pg-backup.log 2>&1
```

备份策略：每日 pg_dump → 压缩 → 上传 OSS，保留 30 天。

---

## 4. 应用机部署

### 4.1 文件准备

需要上传**整个 `deploy/` 目录**到应用机（因为 standalone compose 在 `deploy/` 根目录下）。其中关键文件：

```
deploy/
├── docker-compose.standalone.yml   # sub2api 单独运行的编排（无 PG/Redis）
├── aliyun-sg-planB/app/
│   ├── app.env                     # 环境变量模板
│   ├── Caddyfile                   # TLS 反代配置
│   └── setup-app.sh                # 一键初始化脚本
```

### 4.2 配置环境变量

```bash
cd deploy/aliyun-sg-planB/app
cp app.env .env
nano .env
```

需要修改的项：

| 变量 | 说明 | 示例 |
|---|---|---|
| `DATABASE_HOST` | 数据库机**内网 IP** | `10.0.0.10` |
| `DATABASE_PASSWORD` | 与数据库机 `PG_PASSWORD` 一致 | `a1b2c3d4e5f6g7h8` |
| `REDIS_HOST` | 数据库机**内网 IP** | `10.0.0.10` |
| `REDIS_PASSWORD` | 与数据库机 `REDIS_PASSWORD` 一致 | `x9y8z7w6v5u4t3s2` |
| `ADMIN_EMAIL` | 管理员邮箱 | `admin@example.com` |
| `ADMIN_PASSWORD` | 管理员密码（强密码） | `YourStrongPass123!` |
| `JWT_SECRET` | JWT 密钥（必须固定，否则重启后所有用户登出） | `openssl rand -hex 32` |
| `JWT_EXPIRE_HOUR` | Token 有效期（小时） | `168`（7 天） |

### 4.3 一键初始化

```bash
sudo bash setup-app.sh your-domain.com
```

替换 `your-domain.com` 为你的实际域名。脚本自动完成：
1. 安装 Docker
2. 配置镜像加速
3. 拉取 `weishaw/sub2api:latest` 并启动（standalone 模式，连接数据库机）
4. 启动 Caddy 容器（自动签发 Let's Encrypt TLS 证书）

### 4.4 Caddy 关键配置说明

[Caddyfile](deploy/aliyun-sg-planB/app/Caddyfile) 中有几项**对 LLM 流式输出至关重要**的配置：

```
reverse_proxy 127.0.0.1:8080 {
    flush_interval -1          # 禁用缓冲，收到字节立即转发（SSE 必需）
    transport http {
        read_timeout 0          # 读取无超时（流式响应可能持续数分钟）
        write_timeout 0         # 写入无超时
        dial_timeout 10s
    }
}
```

> **️ 如果不配置 `flush_interval -1`**，Caddy 默认会缓冲响应再转发，导致 LLM token 成块吐出甚至超时断开。

### 4.5 安全说明

- `BIND_HOST=127.0.0.1`：sub2api 只监听本地回环，**不直接暴露公网**。
- 所有公网流量经 Caddy 的 443 端口进入，自动 HTTPS。
- 安全组**不需要**开放 8080 端口。

---

## 5. 运维与升级

### 5.1 常用运维命令

```bash
# === 数据库机 ===
cd db
sudo docker compose -f docker-compose.db.yml ps              # 查看容器状态
sudo docker compose -f docker-compose.db.yml logs -f postgres # PG 日志
sudo docker compose -f docker-compose.db.yml logs -f redis    # Redis 日志
sudo docker compose -f docker-compose.db.yml restart          # 重启全部

# === 应用机 ===
cd deploy
sudo docker compose -f docker-compose.standalone.yml --env-file aliyun-sg-planB/app/.env logs -f sub2api  # sub2api 日志
sudo docker compose -f docker-compose.standalone.yml --env-file aliyun-sg-planB/app/.env restart          # 重启 sub2api
sudo docker logs -f caddy                 # Caddy 日志（含 TLS 签发过程）
```

### 5.2 升级 sub2api

```bash
# 应用机
# 1. 先在数据库机手动跑一次备份
sudo ./pg-backup-to-oss.sh

# 2. 拉取最新镜像并重启
sudo docker pull weishaw/sub2api:latest
sudo docker compose -f docker-compose.standalone.yml --env-file aliyun-sg-planB/app/.env up -d
```

### 5.3 健康检查

```bash
# 验证服务是否正常
curl https://your-domain.com/health
# 应返回：{"status":"ok"}
```

### 5.4 日志查看

```bash
# sub2api 日志（应用机）
sudo docker compose -f docker-compose.standalone.yml --env-file aliyun-sg-planB/app/.env logs --tail=200 sub2api

# Caddy 访问日志（应用机）
tail -f /var/log/caddy/access.log

# PostgreSQL 慢查询日志（数据库机）
sudo docker compose -f docker-compose.db.yml logs --tail=100 postgres | grep "duration"
```

---

## 6. 故障排查

### 数据库连接失败

```bash
# 从应用机测试连通性
telnet 10.0.0.10 5432   # 或 nc -zv 10.0.0.10 5432

# 检查数据库机容器状态
sudo docker compose -f docker-compose.db.yml ps

# 检查安全组规则（确认应用机内网 IP 在允许列表中）
```

### Caddy TLS 签发失败

```bash
# 检查域名解析是否正确
dig your-domain.com

# 检查 80 端口是否对公网开放（Let's Encrypt 验证需要）
curl -I http://your-domain.com

# 查看 Caddy 日志
sudo docker logs caddy
```

### sub2api 启动失败

```bash
# 查看启动日志（admin password 在首次启动日志中）
sudo docker compose -f docker-compose.standalone.yml --env-file aliyun-sg-planB/app/.env logs sub2api | grep "admin password"

# 检查 .env 中 DATABASE_HOST / REDIS_HOST 是否正确填写为数据库机内网 IP
```

---

## 7. 成本估算（月）

| 项目 | 费用（约） |
|---|---|
| ECS 应用机 g8a.large 包年 | ~¥200/月 |
| ECS 数据库机 g8a.large + PL1 100GB 包年 | ~¥230/月 |
| EIP + 流量（30GB） | ~¥45/月 |
| OSS 20GB | ~¥3/月 |
| 域名摊月 | ~¥6/月 |
| **合计** | **~¥484/月** |

> 包年折后实际更低。

---

## 8. 附录：关键文件清单

| 文件 | 位置 | 用途 |
|---|---|---|
| `docker-compose.db.yml` | `deploy/aliyun-sg-planB/db/` | 数据库机：PG18 + Redis8 编排 |
| `.env.db.example` | `deploy/aliyun-sg-planB/db/` | 数据库机环境变量模板 |
| `setup-db.sh` | `deploy/aliyun-sg-planB/db/` | 数据库机一键初始化脚本 |
| `pg-backup-to-oss.sh` | `deploy/aliyun-sg-planB/db/` | PG 每日备份到 OSS 脚本 |
| `docker-compose.standalone.yml` | `deploy/` | 应用机：sub2api 单独运行编排（需整个 deploy/ 目录） |
| `app.env` | `deploy/aliyun-sg-planB/app/` | 应用机环境变量模板 |
| `Caddyfile` | `deploy/aliyun-sg-planB/app/` | Caddy TLS + 反代配置 |
| `setup-app.sh` | `deploy/aliyun-sg-planB/app/` | 应用机一键初始化脚本 |

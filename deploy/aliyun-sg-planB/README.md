# 阿里云新加坡 · 方案 B 部署（应用机 + 数据库机分离）

针对 ~100 人规模的 sub2api 运营部署。两台 ECS：

| 机器 | 规格 | 运行 | 公网 |
|---|---|---|---|
| 应用机 | ecs.g8a.large (2C4G) | sub2api + Caddy | EIP + 80/443 |
| 数据库机 | ecs.g8a.large (2C4G) + 100GB PL1 数据盘 | PostgreSQL 18 + Redis 8（Docker 自建） | 无公网，仅内网 |

两台同一 VPC、同一可用区，内网互通免费。

## 目录结构

```
deploy/aliyun-sg-planB/
├── README.md                 ← 本文件
├── db/                       ← 拷到【数据库机】
│   ├── docker-compose.db.yml ← PG18 + Redis8
│   ├── .env.db.example       ← 复制为 .env 填密码
│   ├── setup-db.sh           ← 一键初始化
│   └── pg-backup-to-oss.sh   ← 每日备份到 OSS
└── app/                      ← 拷到【应用机】
    ├── app.env               ← 复制为 .env 填连接信息
    ├── Caddyfile             ← TLS + 反代（流式关键配置）
    └── setup-app.sh          ← 一键初始化
```

> 应用机还需要仓库里的 `deploy/docker-compose.standalone.yml`，所以拷贝时把整个 `deploy/` 目录都带上。

## 执行顺序

### 第 0 步：阿里云控制台准备
1. 新加坡区建 VPC + 交换机，买 2 台 ECS（Ubuntu 22.04，g8a.large，包年付）
2. 数据库机挂载 ESSD PL1 100GB 数据盘
3. EIP 绑应用机，按使用流量计费，峰值 20Mbps
4. 安全组：
   - **应用机**：入 22（你的 IP）、80、443
   - **数据库机**：入 22（你的 IP）、5432/6379 **仅限应用机内网 IP**
5. 建 OSS Bucket（新加坡），建 RAM 子账号只授该 bucket 读写权限，保存 AK/SK
6. 域名 A 记录指向应用机 EIP

### 第 1 步：数据库机
```bash
# 把 deploy/aliyun-sg-planB/db 整个目录传到数据库机
cd db
cp .env.db.example .env
nano .env                  # 填 PG_PASSWORD / REDIS_PASSWORD（记下来，应用机要用）
bash setup-db.sh
```
记下数据库机内网 IP（控制台看，如 `10.0.0.10`）。

配置定时备份：
```bash
sudo chmod +x pg-backup-to-oss.sh
ossutil config -e oss-ap-southeast-1.aliyuncs.com   # 填 RAM AK/SK
# 测试一次
sudo ./pg-backup-to-oss.sh
# 加 cron：每天 3 点备份
sudo crontab -e
# 添加：0 3 * * * /path/to/pg-backup-to-oss.sh >> /var/log/pg-backup.log 2>&1
```

### 第 2 步：应用机
```bash
# 把整个 deploy/ 目录传到应用机（standalone compose 在 deploy/ 根下）
cd deploy/aliyun-sg-planB/app
cp app.env .env
nano .env                  # 填 DATABASE_HOST / REDIS_HOST（数据库机内网 IP）+ 密码 + JWT_SECRET + ADMIN_*
sudo bash setup-app.sh your-domain.com
```

### 第 3 步：验证
```bash
curl https://your-domain.com/health          # 应返回 {"status":"ok"}
# 浏览器打开 https://your-domain.com，用 .env 里的 ADMIN_EMAIL / ADMIN_PASSWORD 登录
```

## 关键设计说明

### 1. 流式响应（最重要）
[Caddyfile](app/Caddyfile) 里 `flush_interval -1` + `read_timeout 0` 是 LLM 流式输出的命门。Caddy 默认会缓冲响应再转发，会导致 token 成块吐出甚至超时。这两行确保收到字节立即透传。

### 2. 8080 不暴露公网
[app.env](app/app.env) 里 `BIND_HOST=127.0.0.1`，sub2api 只监听本地，公网只能经 Caddy 的 443 进来。安全组不必开 8080。

### 3. 数据库安全
数据库机无 EIP，5432/6379 通过安全组限定仅应用机内网 IP 可访问。即使密码泄露，外网也连不上。

### 4. PG 参数已针对 2C4G 调优
[docker-compose.db.yml](db/docker-compose.db.yml) 里 `shared_buffers=1GB`、`effective_cache_size=2GB`、`max_connections=100`，匹配 4GB 内存机型（留 1GB 给 OS + Redis）。

### 5. 备份双重保险
- PG：每日 pg_dump → OSS，保留 30 天
- 阿里云侧：ECS 系统盘 + 数据盘自动快照（控制台开，免费额度内）

## 运维命令

```bash
# 数据库机
cd db
sudo docker compose -f docker-compose.db.yml ps          # 状态
sudo docker compose -f docker-compose.db.yml logs -f postgres
sudo docker compose -f docker-compose.db.yml restart     # 重启

# 应用机
cd deploy
sudo docker compose -f docker-compose.standalone.yml --env-file aliyun-sg-planB/app/.env logs -f sub2api
sudo docker compose -f docker-compose.standalone.yml --env-file aliyun-sg-planB/app/.env restart
sudo docker logs -f caddy                                 # Caddy 日志（含 TLS 签发）
```

## 升级 sub2api
```bash
# 应用机
sudo docker pull weishaw/sub2api:latest
sudo docker compose -f docker-compose.standalone.yml --env-file aliyun-sg-planB/app/.env up -d
# 升级前务必先在数据库机跑一次 pg-backup-to-oss.sh
```

## 成本（月估）
- ECS 应用机 g8a.large 包年：~¥200
- ECS 数据库机 g8a.large + PL1 100GB 包年：~¥230
- EIP + 流量（30GB）：~¥45
- OSS 20GB：~¥3
- 域名摊月：~¥6
- **合计 ~¥484/月**（包年折后更低）

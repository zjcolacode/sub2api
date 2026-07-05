# 数据库机部署学习笔记

> 整理自 `deploy/aliyun-sg-planB/db/` 和 `deploy/docker-compose*.yml`
> 用途：在其他阿里云账号下快速复现数据库机部署

---

## 一、机器规格

| 项目 | 配置 |
|---|---|
| ECS 规格 | ecs.g8a.large（2 vCPU / 4 GiB） |
| 系统盘 | 40GB ESSD（Ubuntu 22.04） |
| 数据盘 | **ESSD PL1 100GB**（挂载后需格式化挂载，PG 数据存这里） |
| 公网 | **无 EIP**（安全考虑，仅内网访问） |
| 网络 | 与应用机同一 VPC、同一可用区 |

---

## 二、安全组规则（数据库机）

| 端口 | 来源 | 说明 |
|---|---|---|
| 22 (SSH) | 仅你的 IP | 运维管理 |
| 5432 (PG) | **仅应用机内网 IP** | 禁止 0.0.0.0/0 |
| 6379 (Redis) | **仅应用机内网 IP** | 禁止 0.0.0.0/0 |

> ⚠️ **安全红线**：5432/6379 绝不能对 0.0.0.0/0 开放。即使密码泄露，外网也连不上。

---

## 三、PostgreSQL 版本说明

**代码中实际使用版本：PostgreSQL 18**（`postgres:18-alpine`）

涉及文件：
- `deploy/docker-compose.yml:192` → `image: postgres:18-alpine`
- `deploy/docker-compose.local.yml:186` → `image: postgres:18-alpine`
- `deploy/docker-compose.dev.yml:72` → `image: postgres:18-alpine`
- `deploy/aliyun-sg-planB/db/docker-compose.db.yml:5` → `image: postgres:18-alpine`
- `Dockerfile:12` → `ARG POSTGRES_IMAGE=postgres:18-alpine`

> ⚠️ **注意**：之前记忆中认为只支持 PG17，但实际代码已全部升级到 PG18。如需确认兼容性，可查看 `backend/migrations/` 中的 SQL 是否有 PG18 不兼容语法。

---

## 四、Docker Compose 编排（docker-compose.db.yml）

### 4.1 PostgreSQL 容器

```yaml
postgres:
  image: postgres:18-alpine
  container_name: sub2api-postgres
  restart: unless-stopped
  environment:
    POSTGRES_USER: ${PG_USER:-sub2api}
    POSTGRES_PASSWORD: ${PG_PASSWORD:?必填}
    POSTGRES_DB: ${PG_DB:-sub2api}
    TZ: Asia/Shanghai
  command: >
    postgres
    -c max_connections=100
    -c shared_buffers=1GB
    -c effective_cache_size=2GB
    -c maintenance_work_mem=128MB
    -c work_mem=8MB
    -c log_min_duration_statement=1000
  volumes:
    - pg_data:/var/lib/postgresql/data
  ports:
    - "0.0.0.0:5432:5432"
  healthcheck:
    test: ["CMD", "pg_isready", "-U", "${PG_USER:-sub2api}"]
```

### 4.2 Redis 容器

```yaml
redis:
  image: redis:8-alpine
  container_name: sub2api-redis
  restart: unless-stopped
  command: >
    redis-server
    --requirepass ${REDIS_PASSWORD:?必填}
    --appendonly yes
    --save 60 1
    --maxmemory 512mb
    --maxmemory-policy allkeys-lru
  volumes:
    - redis_data:/data
  ports:
    - "0.0.0.0:6379:6379"
  healthcheck:
    test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
```

### 4.3 2C4G 机型 PG 调优参数

| 参数 | 值 | 说明 |
|---|---|---|
| `max_connections` | 100 | 最大连接数（需 ≥ 所有应用实例 MAX_OPEN_CONNS 之和 × 1.2） |
| `shared_buffers` | 1GB | 共享缓存，建议物理内存的 25% |
| `effective_cache_size` | 2GB | 查询规划器假设的 OS 缓存，建议物理内存的 50% |
| `maintenance_work_mem` | 128MB | VACUUM / CREATE INDEX 内存 |
| `work_mem` | 8MB | 排序 / 哈希操作内存 |
| `log_min_duration_statement` | 1000ms | 慢查询日志阈值（≥1s） |

> Redis 占约 512MB（`maxmemory`），OS 预留约 1GB，PG 可用约 2.5GB，所以上述参数是合理的。

---

## 五、环境变量（.env）

```bash
# 复制模板
cp .env.db.example .env

# 需要填写的项
PG_USER=sub2api
PG_PASSWORD=<强密码>        # openssl rand -hex 16
PG_DB=sub2api

REDIS_PASSWORD=<强密码>     # openssl rand -hex 16
```

> ⚠️ `PG_PASSWORD` 和 `REDIS_PASSWORD` 需要同时填入**应用机**的 `.env`（`DATABASE_PASSWORD` / `REDIS_PASSWORD`），两者必须一致。

---

## 六、一键初始化（setup-db.sh）

```bash
bash setup-db.sh
```

脚本流程：
1. **[1/4] 安装 Docker** — `apt install docker.io docker-compose-v2`，加入 docker 组
2. **[2/4] 配置镜像加速** — 写入 `/etc/docker/daemon.json`（daocloud / 1ms.run / ustc）
3. **[3/4] 检查 .env** — 未创建则从 `.env.db.example` 复制并提示填写
4. **[4/4] 启动容器** — `docker compose -f docker-compose.db.yml up -d`

初始化完成后等待 ~12 秒健康检查，`docker compose ps` 确认状态。

---

## 七、每日备份到 OSS（pg-backup-to-oss.sh）

### 7.1 脚本逻辑

```
pg_dump（容器内） → gzip 压缩 → 上传 OSS → 删除 30 天前的旧备份
```

### 7.2 需要修改的配置项

| 变量 | 说明 | 示例 |
|---|---|---|
| `OSS_BUCKET` | Bucket 名称 | `oss://my-sub2api-backup` |
| `OSS_ENDPOINT` | OSS Endpoint | `oss-ap-southeast-1.aliyuncs.com` |
| `OSS_PREFIX` | 备份目录前缀 | `sub2api-backup` |
| `RETAIN_DAYS` | 保留天数 | `30` |

### 7.3 ossutil 配置

```bash
# 首次安装 ossutil
sudo curl -sL -o /usr/local/bin/ossutil https://gosspublic.alicdn.com/ossutil/1.7.18/ossutil64
sudo chmod +x /usr/local/bin/ossutil

# 配置 AK/SK（RAM 子账号，仅授该 Bucket 读写权限）
ossutil config -e oss-ap-southeast-1.aliyuncs.com
```

### 7.4 添加定时任务

```bash
sudo crontab -e
# 每天凌晨 3 点备份
0 3 * * * /path/to/pg-backup-to-oss.sh >> /var/log/pg-backup.log 2>&1
```

### 7.5 备份安全建议

- RAM 子账号**只授目标 Bucket 的读写权限**，不要给全局 OSS 权限
- 升级 sub2api 前**务必先手动跑一次备份**
- 阿里云 ECS 控制台开启**系统盘 + 数据盘自动快照**（免费额度内），作为第二重保险

---

## 八、运维命令速查

```bash
cd db

# 查看容器状态
sudo docker compose -f docker-compose.db.yml ps

# 查看日志
sudo docker compose -f docker-compose.db.yml logs -f postgres
sudo docker compose -f docker-compose.db.yml logs -f redis

# 重启
sudo docker compose -f docker-compose.db.yml restart

# 手动备份
sudo ./pg-backup-to-oss.sh

# 进入 PG 容器执行 SQL
sudo docker exec -it sub2api-postgres psql -U sub2api -d sub2api

# 检查 PG 健康
sudo docker compose -f docker-compose.db.yml exec postgres pg_isready

# 检查 Redis 健康
sudo docker compose -f docker-compose.db.yml exec redis redis-cli -a "$REDIS_PASSWORD" ping
```

---

## 九、常见问题

### Q: 应用机连不上数据库？

1. 检查数据库机安全组：5432/6379 来源是否填了应用机的**内网 IP**（不是 EIP）
2. 从应用机测试连通性：`telnet 10.0.0.x 5432`
3. 检查数据库机容器是否正常运行：`docker compose ps`

### Q: PG 数据盘未挂载？

```bash
# 查看数据盘
lsblk

# 格式化（仅首次）
sudo mkfs.ext4 /dev/vdb

# 挂载
sudo mount /dev/vdb /var/lib/docker

# 写入 fstab 持久化
echo '/dev/vdb /var/lib/docker ext4 defaults 0 2' | sudo tee -a /etc/fstab
```

>  更简单的做法：把数据盘挂载到 `/var/lib/docker`，这样所有 Docker volume 数据自动落在数据盘上。

### Q: 迁移到新账号/新机器的步骤？

1. 数据库机：`docker compose down` → 打包 `pg_data/` 目录 → 传到新机器
2. 新机器：解压到相同路径 → `docker compose up -d`
3. 应用机：修改 `.env` 中的 `DATABASE_HOST` / `REDIS_HOST` 为新数据库机内网 IP

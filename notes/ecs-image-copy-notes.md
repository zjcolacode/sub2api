# ECS 镜像跨账号复制操作指南

> 将已部署好的数据库机和应用机 ECS 镜像快速复制到其他阿里云账号，并列出需要修改的配置文件。

---

## 一、制作自定义镜像

### 1.1 停止实例（推荐）

为了保证数据一致性，制作镜像前**建议先停止实例**（尤其是数据库机）：

```bash
# 数据库机：先停应用机，再停数据库机
# 应用机
sudo docker compose -f docker-compose.standalone.yml --env-file aliyun-sg-planB/app/.env down

# 数据库机
sudo docker compose -f docker-compose.db.yml down
```

> 不停机也可以做镜像（热快照），但数据库机建议停机，避免 PG WAL 不一致。

### 1.2 创建自定义镜像

在阿里云控制台操作：

1. **ECS 控制台** → 实例 → 找到目标实例
2. 点击 **更多** → **云盘和镜像** → **创建自定义镜像**
3. 填写镜像名称和描述（如 `sub2api-db-v1.0`、`sub2api-app-v1.0`）
4. 勾选 **自动快照**（可选，用于回滚）
5. 等待镜像创建完成（状态变为 **可用**）

> 数据库机的镜像会包含系统盘 + 数据盘（100GB PL1），制作时间取决于数据量，通常 10-30 分钟。

---

## 二、跨账号共享镜像

### 方法 A：镜像共享（推荐，同地域）

**适用场景**：目标账号在同一地域（如都是新加坡 ap-southeast-1）

#### 步骤

1. **源账号**：ECS 控制台 → 镜像 → 找到刚创建的自定义镜像
2. 点击 **共享镜像** → **共享**
3. 输入**目标账号的阿里云 UID**（16 位数字，在账号管理中查看）
4. 目标账号收到共享镜像后，在镜像列表中可以看到（标记为"共享镜像"）
5. 目标账号用该共享镜像**创建实例**

> 镜像共享是免费的，不产生额外费用。共享后源镜像删除不影响已共享的镜像。

### 方法 B：跨地域复制镜像

**适用场景**：目标账号在不同地域

1. **源账号**：镜像 → 复制镜像 → 选择目标地域
2. 等待复制完成
3. 再按方法 A 共享给目标账号

### 方法 C：导出/导入镜像（跨账号 + 跨地域通用）

**适用场景**：镜像共享不满足需求时

#### 导出镜像到 OSS

1. 镜像 → 导出镜像 → 选择 OSS Bucket
2. 导出格式选 **qcow2** 或 **vhd**
3. 等待导出完成（大镜像可能需要 1-2 小时）

#### 目标账号导入镜像

1. 目标账号 OSS 中获取镜像文件（可先共享 Bucket 或下载到本地再上传）
2. ECS 控制台 → 镜像 → **导入镜像**
3. 选择 OSS 中的镜像文件，填写操作系统类型（Linux）
4. 等待导入完成

---

## 三、用镜像创建新实例

### 3.1 创建数据库机

1. ECS 控制台 → **创建实例** → **自定义购买**
2. 付费模式选 **按量付费**（先测试，确认没问题再转包年包月）
3. 地域/可用区选与原机器**相同**（VPC 内网互通的前提）
4. 实例规格选 **ecs.g8a.large**（2C4G，与原机器一致）
5. 镜像选择 → **共享镜像** → 选择 `sub2api-db-v1.0`
6. 系统盘：ESSD 40GB
7. **数据盘**：ESSD PL1 100GB（️ 必须挂载，PG 数据在这里）
8. 网络：选择目标账号的 VPC + 交换机（需与原应用机同 VPC 同可用区）
9. 公网带宽：**不分配**（数据库机不需要 EIP）
10. 安全组：按 [数据库机安全组规则](#数据库机安全组规则新账号) 配置

### 3.2 创建应用机

1. 同上步骤，镜像选择 `sub2api-app-v1.0`
2. 规格：ecs.g8a.large（2C4G）
3. 数据盘：**不需要**（应用机无数据盘）
4. 网络：与数据库机**同一 VPC、同一可用区**
5. 公网带宽：分配 EIP，按使用流量计费，峰值 20Mbps
6. 安全组：按 [应用机安全组规则](#应用机安全组规则新账号) 配置

---

## 四、新账号需要修改的配置文件

### ⚠️ 核心变更项

镜像复制后，**以下配置必须修改**，否则服务无法正常运行：

---

### 4.1 数据库机

#### (1) `.env` 文件

**路径**：`db/.env`

| 配置项 | 是否需要修改 | 说明 |
|---|---|---|
| `PG_USER` | ❌ 不需要 | 默认 `sub2api`，保持不变 |
| `PG_PASSWORD` | ❌ 不需要 | 密码在镜像中已存在，保持不变 |
| `PG_DB` | ❌ 不需要 | 默认 `sub2api` |
| `REDIS_PASSWORD` | ❌ 不需要 | 密码已存在 |

> 数据库机的 `.env` **不需要修改**，密码和用户名都是应用层面的，与网络无关。

#### (2) 安全组规则（新账号必须重新配置）

| 端口 | 来源 | 操作 |
|---|---|---|
| 22 (SSH) | 你的新 IP | 入方向允许 |
| 5432 (PG) | **新应用机的内网 IP** | 入方向允许（⚠️ 不是旧 IP） |
| 6379 (Redis) | **新应用机的内网 IP** | 入方向允许（⚠️ 不是旧 IP） |

> ⚠️ **最关键的一步**：新账号的 VPC 网段可能与原账号不同，应用机的内网 IP 会变。必须用**新应用机的实际内网 IP** 更新数据库机安全组规则。

#### (3) 数据盘挂载检查

新实例创建后，检查数据盘是否自动挂载：

```bash
# 查看磁盘
lsblk

# 如果数据盘未挂载（没有显示在 /var/lib/docker 下）
# 查看 UUID
sudo blkid /dev/vdb

# 编辑 fstab
sudo nano /etc/fstab
# 添加（用实际 UUID）：
# UUID=xxxx /var/lib/docker ext4 defaults 0 2

# 挂载
sudo mount -a

# 验证
df -h /var/lib/docker
```

> 镜像中如果已配置 fstab，新实例通常会**自动挂载**（云盘 UUID 会变，但阿里云的云助手通常会处理）。如果 Docker 启动后数据丢失，说明数据盘没挂载上，需要手动处理。

---

### 4.2 应用机

#### (1) `.env` 文件（⚠️ 必须修改）

**路径**：`deploy/aliyun-sg-planB/app/.env`

| 配置项 | 是否需要修改 | 说明 |
|---|---|---|
| `DATABASE_HOST` | ✅ **必须修改** | 改为新数据库机的**内网 IP** |
| `REDIS_HOST` | ✅ **必须修改** | 改为新数据库机的**内网 IP** |
| `DATABASE_PASSWORD` | ❌ 不需要 | 与数据库机 PG_PASSWORD 一致，已存在 |
| `REDIS_PASSWORD` | ❌ 不需要 | 与数据库机 REDIS_PASSWORD 一致，已存在 |
| `BIND_HOST` |  不需要 | 保持 `127.0.0.1` |
| `SERVER_PORT` | ❌ 不需要 | 保持 `8080` |
| `JWT_SECRET` |  不需要 | 必须保持原值，否则所有用户登出 |
| `TOTP_ENCRYPTION_KEY` | ❌ 不需要 | 必须保持原值，否则 2FA 失效 |
| `ADMIN_EMAIL` | ❌ 不需要 | 已存在 |
| `ADMIN_PASSWORD` | ❌ 不需要 | 已存在 |
| `DOMAIN` | ✅ **如果需要换域名** | 修改为新域名 |

**操作**：
```bash
cd deploy/aliyun-sg-planB/app
nano .env
# 修改 DATABASE_HOST 和 REDIS_HOST 为新数据库机内网 IP
```

#### (2) Caddyfile 域名（如果需要换域名）

**路径**：`deploy/aliyun-sg-planB/app/Caddyfile`

如果新账号使用不同域名，需要修改 Caddyfile 中的域名，或者通过 `setup-app.sh` 重新传入新域名重启 Caddy：

```bash
# 方法：直接重新运行 setup-app.sh（会重建 Caddy 容器）
sudo bash setup-app.sh new-domain.com
```

#### (3) 安全组规则（新账号必须重新配置）

| 端口 | 来源 | 操作 |
|---|---|---|
| 22 (SSH) | 你的新 IP | 入方向允许 |
| 80 (HTTP) | 0.0.0.0/0 | 入方向允许（Caddy TLS 验证需要） |
| 443 (HTTPS) | 0.0.0.0/0 | 入方向允许 |
| 8080 | **不开放** | 仅 Caddy 本地访问，不需要开 |

#### (4) 域名 DNS

如果换了域名，需要更新 DNS A 记录，指向新应用机的 EIP。

---

## 五、启动验证清单

### 5.1 数据库机

```bash
# 1. 确认数据盘已挂载
df -h /var/lib/docker

# 2. 启动 Docker 服务
sudo systemctl start docker

# 3. 启动 PG + Redis
cd db
sudo docker compose -f docker-compose.db.yml up -d

# 4. 等待健康检查
sleep 12
sudo docker compose -f docker-compose.db.yml ps

# 5. 验证 PG
sudo docker exec -it sub2api-postgres pg_isready
# 应返回：/var/run/postgresql:5432 - accepting connections

# 6. 验证 Redis
sudo docker exec sub2api-redis redis-cli -a "$REDIS_PASSWORD" ping
# 应返回：PONG

# 7. 查看数据库机内网 IP（应用机需要）
hostname -I
# 或
ip addr show eth0 | grep 'inet '
```

### 5.2 应用机

```bash
# 1. 确认 .env 中 DATABASE_HOST / REDIS_HOST 已改为新内网 IP
grep -E "DATABASE_HOST|REDIS_HOST" deploy/aliyun-sg-planB/app/.env

# 2. 启动 sub2api
cd deploy
sudo docker compose -f docker-compose.standalone.yml \
  --env-file aliyun-sg-planB/app/.env up -d

# 3. 启动 Caddy（如果域名不变，Caddy 会自动续期证书）
sudo docker rm -f caddy 2>/dev/null || true
sudo docker run -d --name caddy \
  --restart unless-stopped \
  --network host \
  -e DOMAIN="your-domain.com" \
  -v "$PWD/aliyun-sg-planB/app/Caddyfile:/etc/caddy/Caddyfile:ro" \
  -v caddy_data:/data \
  -v caddy_config:/config \
  -v /var/log/caddy:/var/log/caddy \
  caddy:2-alpine

# 4. 健康检查
sleep 15
curl -sk https://your-domain.com/health
# 应返回：{"status":"ok"}

# 5. 登录验证
# 浏览器打开 https://your-domain.com，用原账号密码登录
```

---

## 六、完整操作顺序总结

```
┌─────────────────────────────────────────────────────────┐
│ 源账号                                                   │
│ 1. 停应用机 Docker                                       │
│ 2. 停数据库机 Docker                                     │
│ 3. 两台 ECS 分别创建自定义镜像                             │
│ 4. 镜像共享给目标账号 UID                                  │
└──────────────────────┬──────────────────────────────────┘
                       │
──────────────────────▼──────────────────────────────────
│ 目标账号                                                 │
│ 5. 创建数据库机实例（共享镜像 + 挂载数据盘 + 无 EIP）        │
│ 6. 创建应用机实例（共享镜像 + EIP）                        │
│ 7. 数据库机：检查数据盘挂载 → 启动 Docker → 启动 PG+Redis  │
│ 8. 记录数据库机内网 IP                                    │
│ 9. 应用机：修改 .env 中 DATABASE_HOST / REDIS_HOST        │
│ 10. 应用机：配置安全组（22/80/443）                        │
│ 11. 数据库机：配置安全组（5432/6379 → 新应用机内网 IP）     │
│ 12. 应用机：启动 sub2api + Caddy                          │
│ 13. curl https://域名/health 验证                          │
│ 14. 浏览器登录验证                                        │
│ 15. 配置 OSS 备份（pg-backup-to-oss.sh + crontab）        │
─────────────────────────────────────────────────────────┘
```

---

## 七、注意事项

### 7.1 JWT_SECRET 和 TOTP_ENCRYPTION_KEY

这两个值**必须保持原值**，不能重新生成：
- `JWT_SECRET` 变了 → 所有已登录用户 Session 失效，需要重新登录
- `TOTP_ENCRYPTION_KEY` 变了 → 所有用户的 2FA 配置失效，无法使用双因素认证登录

镜像中已包含原值，**不要重新运行 `setup-app.sh` 覆盖 `.env`**（它会生成新密钥）。

### 7.2 Docker Volume 数据

- 数据库机的 PG 数据在**数据盘**上（`/var/lib/docker` → `pg_data` volume）
- 应用机的 sub2api 数据在**系统盘**的 Docker volume 中（`config.yaml`、上传文件等）
- 镜像会包含 Docker volume 数据，所以迁移后数据是完整的

### 7.3 Caddy TLS 证书

- Caddy 证书存在 `caddy_data` volume 中，镜像已包含
- 如果**域名不变**，Caddy 会自动续期，无需额外操作
- 如果**换了域名**，Caddy 会自动为新域名签发证书（需要 80 端口可访问）

### 7.4 跨地域注意事项

- 如果目标账号在不同地域，镜像需要先**复制镜像**到目标地域，再共享
- 跨地域后，内网 IP 段不同，安全组规则需要重新配置
- OSS 备份的 Endpoint 也要改为目标地域的 OSS Endpoint

### 7.5 费用

- 自定义镜像存储：免费（与快照共用额度）
- 镜像共享：免费
- 跨地域复制镜像：按快照存储收费（约 ¥0.35/GB/月）
- 新实例：按新账号的 ECS 定价计费

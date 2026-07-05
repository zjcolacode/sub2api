#!/usr/bin/env bash
# PG 每日备份到阿里云 OSS，保留 30 天
# 用法（数据库机 root crontab）：
#   0 3 * * * /path/to/pg-backup-to-oss.sh >> /var/log/pg-backup.log 2>&1
set -euo pipefail

# ===== 配置（按实际填写）=====
PG_CONTAINER=sub2api-postgres
PG_USER=sub2api
PG_DB=sub2api
OSS_BUCKET=oss://your-bucket-name             # 改成你的 bucket 名
OSS_ENDPOINT=oss-ap-southeast-1.aliyuncs.com  # 新加坡内网/外网 endpoint
OSS_PREFIX=sub2api-backup
RETAIN_DAYS=30
# ============================

# 安装 ossutil（首次）
OSSUTIL=/usr/local/bin/ossutil
if [ ! -x "$OSSUTIL" ]; then
  echo "==> 安装 ossutil..."
  sudo curl -sL -o "$OSSUTIL" https://gosspublic.alicdn.com/ossutil/1.7.18/ossutil64
  sudo chmod +x "$OSSUTIL"
  echo "==> 请先运行一次配置（RAM 子账号 AK/SK，仅授 OSS 读写权限）："
  echo "    ossutil config -e $OSS_ENDPOINT"
  echo "    配完再跑本脚本。"
  exit 1
fi

DATE=$(date +%Y%m%d-%H%M%S)
TMP=/tmp/pg-backup
mkdir -p "$TMP"
FILE="$TMP/sub2api-$DATE.sql.gz"

echo "[$DATE] 开始 pg_dump..."
docker exec -t "$PG_CONTAINER" pg_dump -U "$PG_USER" -d "$PG_DB" --no-owner --clean --if-exists | gzip > "$FILE"

echo "==> 上传到 OSS..."
"$OSSUTIL" cp "$FILE" "$OSS_BUCKET/$OSS_PREFIX/sub2api-$DATE.sql.gz" -e "$OSS_ENDPOINT" -f

rm -f "$FILE"

echo "==> 删除 ${RETAIN_DAYS} 天前的旧备份..."
CUTOFF=$(date -d "-${RETAIN_DAYS} days" +%Y%m%d)
"$OSSUTIL" ls "$OSS_BUCKET/$OSS_PREFIX/" -e "$OSS_ENDPOINT" 2>/dev/null \
  | grep -oE "sub2api-[0-9]{8}-[0-9]{6}\.sql\.gz" | sort -u \
  | while read -r f; do
      d=${f:8:8}  # sub2api-YYYYMMDD-HHMMSS
      if [[ "$d" < "$CUTOFF" ]]; then
        "$OSSUTIL" rm "$OSS_BUCKET/$OSS_PREFIX/$f" -e "$OSS_ENDPOINT" -f
        echo "    已删 $f"
      fi
    done

echo "[$DATE] 备份完成。"

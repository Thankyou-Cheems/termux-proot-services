#!/bin/bash
# 仅更新 MCSManager

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/backups/${DATE}"
mkdir -p "${BACKUP_DIR}/mcs"

log_info "备份 MCSManager 配置..."
cp -r /opt/mcsmanager/daemon/data/Config "${BACKUP_DIR}/mcs/" 2>/dev/null || true
cp -r /opt/mcsmanager/web/data/SystemConfig "${BACKUP_DIR}/mcs/" 2>/dev/null || true

log_info "停止 MCSManager..."
pm2 stop mcs-daemon || true
pm2 stop mcs-web || true

cd /opt/mcsmanager
log_info "拉取最新代码..."
git pull --quiet

log_info "安装依赖 (pnpm)..."
cd daemon && pnpm install --production --no-fund --no-audit --loglevel=error
cd ../web && pnpm install --production --no-fund --no-audit --loglevel=error

log_info "启动服务..."
pm2 start mcs-daemon
pm2 start mcs-web
pm2 save --force
log_info "✓ MCSManager 更新完成！备份：${BACKUP_DIR}"

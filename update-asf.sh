#!/bin/bash
# 仅更新 ASF

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/backups/${DATE}"
mkdir -p "${BACKUP_DIR}/ASF"

log_info "备份 ASF 配置..."
cp -r /opt/ASF/config/* "${BACKUP_DIR}/ASF/" 2>/dev/null || true

log_info "停止 ASF..."
pm2 stop asf

cd /opt/ASF
LATEST_VERSION=$(curl -s https://api.github.com/repos/JustArchiNET/ArchiSteamFarm/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
log_info "更新到 ${LATEST_VERSION}..."

wget -q --show-progress "https://github.com/JustArchiNET/ArchiSteamFarm/releases/download/${LATEST_VERSION}/ASF-linux-arm64.zip" -O /tmp/ASF-update.zip
unzip -q /tmp/ASF-update.zip -d /tmp/ASF-new/
rsync -a --exclude='config/' --exclude='*.json' --exclude='*.db' /tmp/ASF-new/ /opt/ASF/
rm -f /tmp/ASF-update.zip
rm -rf /tmp/ASF-new/

log_info "启动 ASF..."
pm2 start asf
pm2 save --force
log_info "✓ ASF 更新完成！备份：${BACKUP_DIR}"

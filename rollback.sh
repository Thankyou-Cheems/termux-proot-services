#!/bin/bash
# MCSManager + ASF 快速回滚脚本
# 用于更新失败时恢复配置

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 查找最新备份
LATEST_BACKUP=$(ls -td /opt/backups/*/ 2>/dev/null | head -1)

if [ -z "${LATEST_BACKUP}" ]; then
    log_error "未找到备份目录！"
    exit 1
fi

log_info "使用备份：${LATEST_BACKUP}"

# 停止服务
log_info "停止服务..."
pm2 stop all || true

# 恢复 ASF 配置
log_info "恢复 ASF 配置..."
cp -r "${LATEST_BACKUP}ASF/config/"* /opt/ASF/config/ 2>/dev/null || true
cp "${LATEST_BACKUP}ASF/"*.json /opt/ASF/ 2>/dev/null || true

# 恢复 MCSManager 配置
log_info "恢复 MCSManager 配置..."
cp -r "${LATEST_BACKUP}mcsmanager/daemon/Config" /opt/mcsmanager/daemon/data/ 2>/dev/null || true
cp -r "${LATEST_BACKUP}mcsmanager/daemon/InstanceConfig" /opt/mcsmanager/daemon/data/ 2>/dev/null || true
cp -r "${LATEST_BACKUP}mcsmanager/daemon/InstanceData" /opt/mcsmanager/daemon/data/ 2>/dev/null || true
cp -r "${LATEST_BACKUP}mcsmanager/daemon/TaskConfig" /opt/mcsmanager/daemon/data/ 2>/dev/null || true

cp -r "${LATEST_BACKUP}mcsmanager/web/SystemConfig" /opt/mcsmanager/web/data/ 2>/dev/null || true
cp -r "${LATEST_BACKUP}mcsmanager/web/User" /opt/mcsmanager/web/data/ 2>/dev/null || true

# 重启服务
log_info "重启服务..."
pm2 start all
pm2 save --force

log_info "✓ 配置恢复完成！"

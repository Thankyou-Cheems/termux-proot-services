#!/bin/bash
# MCSManager + ASF 更新脚本
# 功能：安全更新业务，保留所有配置文件

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 获取当前日期用于备份
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/backups/${DATE}"

# ============================================
# 创建备份目录
# ============================================
log_info "创建备份目录：${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/ASF"
mkdir -p "${BACKUP_DIR}/mcsmanager/daemon"
mkdir -p "${BACKUP_DIR}/mcsmanager/web"

# ============================================
# 备份 ASF 配置
# ============================================
log_info "备份 ASF 配置..."
cp -r /opt/ASF/config/* "${BACKUP_DIR}/ASF/config/" 2>/dev/null || true
cp /opt/ASF/ASF.json "${BACKUP_DIR}/ASF/" 2>/dev/null || true
cp /opt/ASF/IPC.config "${BACKUP_DIR}/ASF/" 2>/dev/null || true

# ============================================
# 备份 MCSManager 配置
# ============================================
log_info "备份 MCSManager 配置..."
cp -r /opt/mcsmanager/daemon/data/Config "${BACKUP_DIR}/mcsmanager/daemon/"
cp -r /opt/mcsmanager/daemon/data/InstanceConfig "${BACKUP_DIR}/mcsmanager/daemon/"
cp -r /opt/mcsmanager/daemon/data/InstanceData "${BACKUP_DIR}/mcsmanager/daemon/" 2>/dev/null || true
cp -r /opt/mcsmanager/daemon/data/TaskConfig "${BACKUP_DIR}/mcsmanager/daemon/"

cp -r /opt/mcsmanager/web/data/SystemConfig "${BACKUP_DIR}/mcsmanager/web/"
cp -r /opt/mcsmanager/web/data/User "${BACKUP_DIR}/mcsmanager/web/"
cp -r /opt/mcsmanager/web/data/RemoteServiceConfig "${BACKUP_DIR}/mcsmanager/web/" 2>/dev/null || true
cp -r /opt/mcsmanager/web/data/operation_logs "${BACKUP_DIR}/mcsmanager/web/" 2>/dev/null || true
cp /opt/mcsmanager/web/data/current-version.txt "${BACKUP_DIR}/mcsmanager/web/" 2>/dev/null || true
cp /opt/mcsmanager/web/data/market_cache.json "${BACKUP_DIR}/mcsmanager/web/" 2>/dev/null || true

log_info "备份完成：${BACKUP_DIR}"

# ============================================
# 更新 ASF
# ============================================
log_info "========== 更新 ArchiSteamFarm =========="

# 获取当前版本
CURRENT_ASF_VERSION=$(grep -o 'V[0-9.]*' /opt/ASF/log.txt 2>/dev/null | head -1 | tr -d 'V' || echo "unknown")
log_info "当前 ASF 版本：${CURRENT_ASF_VERSION}"

# 停止 ASF
log_info "停止 ASF..."
pm2 stop asf || true

# 下载最新版本
cd /opt/ASF
LATEST_VERSION=$(curl -s https://api.github.com/repos/JustArchiNET/ArchiSteamFarm/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
log_info "最新版本：${LATEST_VERSION}"

if [ "${CURRENT_ASF_VERSION}" = "${LATEST_VERSION}" ]; then
    log_warn "ASF 已是最新版本，跳过更新"
    pm2 start asf
else
    log_info "下载 ASF ${LATEST_VERSION}..."
    wget -q --show-progress "https://github.com/JustArchiNET/ArchiSteamFarm/releases/download/${LATEST_VERSION}/ASF-linux-arm64.zip" -O /tmp/ASF-update.zip
    
    log_info "解压更新（保留配置文件）..."
    # 解压到临时目录
    unzip -q /tmp/ASF-update.zip -d /tmp/ASF-new/
    
    # 复制新文件，但跳过配置文件
    rsync -a --exclude='config/' --exclude='*.json' --exclude='*.db' /tmp/ASF-new/ /opt/ASF/
    
    # 清理
    rm -f /tmp/ASF-update.zip
    rm -rf /tmp/ASF-new/
    
    log_info "ASF 更新完成！"
    pm2 start asf
fi

# ============================================
# 更新 MCSManager
# ============================================
log_info "========== 更新 MCSManager =========="

# 获取当前版本
CURRENT_MCS_VERSION=$(cat /opt/mcsmanager/daemon/package.json | grep '"version"' | head -1 | cut -d'"' -f4)
log_info "当前 MCSManager 版本：${CURRENT_MCS_VERSION}"

# 停止服务
log_info "停止 MCSManager 服务..."
pm2 stop mcs-daemon || true
pm2 stop mcs-web || true

# 从 Gitee 获取最新版本（国内镜像）
LATEST_VERSION=$(curl -s https://gitee.com/api/v5/repos/mcsmanager/MCSManager/releases/latest | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4)
if [ -z "${LATEST_VERSION}" ]; then
    # Gitee API 失败时回退到 GitHub
    LATEST_VERSION=$(curl -s https://api.github.com/repos/MCSManager/MCSManager/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
fi
log_info "最新版本：${LATEST_VERSION}"

if [ "${CURRENT_MCS_VERSION}" = "${LATEST_VERSION}" ]; then
    log_warn "MCSManager 已是最新版本，跳过更新"
    pm2 start mcs-daemon
    pm2 start mcs-web
else
    log_info "从 Gitee 下载 MCSManager ${LATEST_VERSION}..."
    cd /tmp
    
    # 使用 Gitee 下载（国内更快）
    DOWNLOAD_URL="https://gitee.com/mcsmanager/MCSManager/archive/refs/tags/${LATEST_VERSION}.zip"
    
    if curl -sL --connect-timeout 30 --max-time 300 "${DOWNLOAD_URL}" -o mcs-update.zip; then
        if [ -s mcs-update.zip ]; then
            log_info "解压更新..."
            rm -rf /tmp/mcs-new/
            unzip -q mcs-update.zip -d /tmp/mcs-new/
            
            # 检查新版本的目录结构
            NEW_DIR="/tmp/mcs-new/MCSManager-${LATEST_VERSION}"
            if [ -d "${NEW_DIR}/daemon" ] && [ -d "${NEW_DIR}/panel" ]; then
                # v10+ 新结构：daemon 和 panel 分离
                log_info "检测到新版结构 (v10+)..."
                cp -rf "${NEW_DIR}/daemon/"* /opt/mcsmanager/daemon/
                cp -rf "${NEW_DIR}/panel/"* /opt/mcsmanager/web/
            elif [ -d "${NEW_DIR}/daemon" ] && [ -d "${NEW_DIR}/web" ]; then
                # 旧版结构
                log_info "检测到旧版结构..."
                cp -rf "${NEW_DIR}/daemon/"* /opt/mcsmanager/daemon/
                cp -rf "${NEW_DIR}/web/"* /opt/mcsmanager/web/
            else
                log_error "未知的目录结构，跳过更新"
                pm2 start mcs-daemon
                pm2 start mcs-web
                return
            fi
            
            # 使用 pnpm 安装依赖
            log_info "安装依赖 (pnpm)..."
            cd /opt/mcsmanager/daemon
            pnpm install --production --loglevel=error 2>/dev/null || pnpm install --prod --loglevel=error 2>/dev/null || pnpm install --production 2>&1 | tail -5
            
            cd /opt/mcsmanager/web
            pnpm install --production --loglevel=error 2>/dev/null || pnpm install --prod --loglevel=error 2>/dev/null || pnpm install --production 2>&1 | tail -5
            
            # 清理
            rm -f /tmp/mcs-update.zip
            rm -rf /tmp/mcs-new/
            
            log_info "MCSManager 更新完成！"
        else
            log_error "下载文件为空，跳过 MCSManager 更新"
        fi
    else
        log_error "下载失败，跳过 MCSManager 更新"
    fi
    pm2 start mcs-daemon
    pm2 start mcs-web
fi

# ============================================
# 验证配置完整性
# ============================================
log_info "========== 验证配置 =========="

# 检查 ASF 配置
if [ -f /opt/ASF/config/ASF.json ]; then
    log_info "✓ ASF 主配置完整"
else
    log_error "✗ ASF 主配置丢失！从备份恢复..."
    cp "${BACKUP_DIR}/ASF/config/"* /opt/ASF/config/ 2>/dev/null || true
fi

# 检查 MCSManager 配置 (v10 结构：global.json)
if [ -f /opt/mcsmanager/daemon/data/Config/global.json ] || [ -f /opt/mcsmanager/daemon/data/Config/config.json ]; then
    log_info "✓ MCSManager Daemon 配置完整"
else
    log_error "✗ MCSManager Daemon 配置丢失！从备份恢复..."
    cp -r "${BACKUP_DIR}/mcsmanager/daemon/Config" /opt/mcsmanager/daemon/data/ 2>/dev/null || true
fi

if [ -f /opt/mcsmanager/web/data/SystemConfig/config.json ]; then
    log_info "✓ MCSManager Web 配置完整"
else
    log_error "✗ MCSManager Web 配置丢失！从备份恢复..."
    cp -r "${BACKUP_DIR}/mcsmanager/web/SystemConfig" /opt/mcsmanager/web/data/ 2>/dev/null || true
fi

# ============================================
# 保存 PM2 配置
# ============================================
log_info "保存 PM2 进程列表..."
pm2 save --force

# ============================================
# 显示状态
# ============================================
echo ""
log_info "========== 更新完成 =========="
echo ""
pm2 list
echo ""
log_info "备份位置：${BACKUP_DIR}"
log_info "如需恢复备份，请运行："
echo "  cp ${BACKUP_DIR}/ASF/config/* /opt/ASF/config/"
echo "  cp ${BACKUP_DIR}/mcsmanager/daemon/Config /opt/mcsmanager/daemon/data/"
echo "  cp ${BACKUP_DIR}/mcsmanager/web/SystemConfig /opt/mcsmanager/web/data/"

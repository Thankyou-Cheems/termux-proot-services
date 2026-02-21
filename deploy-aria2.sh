#!/bin/bash
# Aria2 + AriaNg + Caddy 一键部署脚本
# 使用国内镜像站加速

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# ============================================
# 配置变量
# ============================================
ARIA2_DIR="/opt/aria2"
ARIANG_DIR="/opt/ariang"
CADDY_DIR="/opt/caddy"
DOWNLOAD_DIR="/opt/aria2/data"

# 镜像站配置
GITHUB_MIRROR="https://mirror.ghproxy.com/https://github.com"
ARIA2_CONFIG_URL="https://raw.githubusercontent.com/P3TERX/aria2.conf/master/aria2.conf"

# RPC 密钥 (随机生成)
RPC_SECRET=$(openssl rand -hex 16)

# ============================================
# 检查系统
# ============================================
log_step "检查系统环境..."
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "x86_64" ]; then
    log_error "不支持的架构：$ARCH"
    exit 1
fi
log_info "架构：$ARCH"

# ============================================
# 创建目录结构
# ============================================
log_step "创建目录结构..."
mkdir -p ${ARIA2_DIR}/{config,data,logs}
mkdir -p ${ARIANG_DIR}
mkdir -p ${CADDY_DIR}
log_info "目录创建完成"

# ============================================
# 安装 Aria2
# ============================================
log_step "安装 Aria2..."
if command -v aria2c &> /dev/null; then
    log_info "Aria2 已安装，跳过"
else
    apt-get update -qq
    apt-get install -y aria2
fi
log_info "Aria2 安装完成"

# ============================================
# 配置 Aria2
# ============================================
log_step "配置 Aria2..."

cat > ${ARIA2_DIR}/config/aria2.conf << EOF
# ===== 基本配置 =====
# 下载文件保存路径
dir=${DOWNLOAD_DIR}

# 日志文件
log=${ARIA2_DIR}/logs/aria2.log
log-level=warn

# 从会话文件中读取下载任务
input-file=${ARIA2_DIR}/config/aria2.session
save-session=${ARIA2_DIR}/config/aria2.session
save-session-interval=60

# ===== 下载配置 =====
# 最大同时下载任务数
max-concurrent-downloads=5

# 单文件最大连接数
max-connection-per-server=16

# 最小文件分片大小
min-split-size=10M

# 断点续传
continue=true

# 文件预分配
file-allocation=none

# ===== RPC 配置 =====
# 启用 RPC
enable-rpc=true
rpc-listen-all=true
rpc-listen-port=6800

# RPC 密钥
rpc-secret=${RPC_SECRET}

# 允许来源
rpc-allow-origin-all=true

# ===== BT 配置 =====
# 启用 DHT
enable-dht=true
enable-dht6=true

# DHT 监听端口
dht-listen-port=6881-6999

# BT 监听端口
listen-port=6881-6999

# 启用 PE
enable-peer-exchange=true

# 用户代理
user-agent=Wget/1.21

# referer
referer=*

# 禁用 IPv6
disable-ipv6=false

# 优化配置
max-overall-download-limit=0
max-overall-upload-limit=0
EOF

# 创建空会话文件
touch ${ARIA2_DIR}/config/aria2.session

log_info "Aria2 配置完成"
log_info "RPC 密钥：${RPC_SECRET}"

# ============================================
# 下载 AriaNg
# ============================================
log_step "下载 AriaNg..."
cd /tmp

# 获取最新版本
ARIANG_LATEST=$(curl -s https://api.github.com/repos/mayswind/AriaNg/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
if [ -z "$ARIANG_LATEST" ]; then
    ARIANG_LATEST="1.3.7"
    log_warn "无法获取最新版本，使用默认版本：${ARIANG_LATEST}"
fi

log_info "AriaNg 版本：${ARIANG_LATEST}"

# 使用镜像站下载
DOWNLOAD_URL="${GITHUB_MIRROR}/mayswind/AriaNg/releases/download/${ARIANG_LATEST}/AriaNg-${ARIANG_LATEST}-AllInOne.zip"
log_info "下载地址：${DOWNLOAD_URL}"

curl -sL --connect-timeout 30 --max-time 300 "${DOWNLOAD_URL}" -o /tmp/ariang.zip

if [ -s /tmp/ariang.zip ]; then
    unzip -q -o /tmp/ariang.zip -d ${ARIANG_DIR}/
    # 如果下载的是 zip 文件，可能需要调整目录
    if [ -f "${ARIANG_DIR}/index.html" ]; then
        log_info "AriaNg 文件已在正确位置"
    elif [ -d "${ARIANG_DIR}/AriaNg" ]; then
        mv ${ARIANG_DIR}/AriaNg/* ${ARIANG_DIR}/
        rm -rf ${ARIANG_DIR}/AriaNg
    fi
    rm -f /tmp/ariang.zip
    log_info "AriaNg 下载完成"
else
    log_error "AriaNg 下载失败，尝试备用方案..."
    # 备用方案：使用 CDN
    curl -sL "https://cdn.jsdelivr.net/gh/mayswind/AriaNg@${ARIANG_LATEST}/index.html" -o ${ARIANG_DIR}/index.html
    if [ -s ${ARIANG_DIR}/index.html ]; then
        log_info "使用 CDN 备用方案成功"
    else
        log_error "所有下载方式均失败，请检查网络"
        exit 1
    fi
fi

# ============================================
# 安装 Caddy
# ============================================
log_step "安装 Caddy..."

if command -v caddy &> /dev/null; then
    log_info "Caddy 已安装，跳过"
else
    # 添加 Caddy 官方 GPG 密钥
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
    apt-get update -qq
    apt-get install -y caddy
fi
log_info "Caddy 安装完成"

# ============================================
# 配置 Caddy
# ============================================
log_step "配置 Caddy..."

cat > ${CADDY_DIR}/Caddyfile << EOF
:80 {
    root * ${ARIANG_DIR}
    file_server

    # Aria2 RPC 反向代理
    handle /jsonrpc* {
        reverse_proxy localhost:6800
    }
    
    # WebSocket 支持
    handle /ws {
        reverse_proxy localhost:6800
    }
}
EOF

log_info "Caddy 配置完成"

# ============================================
# 创建 systemd 服务 (Aria2)
# ============================================
log_step "创建 Aria2 系统服务..."

cat > /etc/systemd/system/aria2.service << EOF
[Unit]
Description=Aria2 Download Manager
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/aria2c --conf-path=${ARIA2_DIR}/config/aria2.conf --daemon=false
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable aria2.service

log_info "Aria2 服务创建完成"

# ============================================
# 启动服务
# ============================================
log_step "启动服务..."

# 启动 Aria2
systemctl restart aria2
sleep 2

# 检查 Aria2 状态
if systemctl is-active --quiet aria2; then
    log_info "Aria2 启动成功"
else
    log_error "Aria2 启动失败，检查日志：${ARIA2_DIR}/logs/aria2.log"
    exit 1
fi

# 启动/重载 Caddy
if systemctl is-active --quiet caddy; then
    systemctl reload caddy
else
    systemctl restart caddy
fi
sleep 2

if systemctl is-active --quiet caddy; then
    log_info "Caddy 启动成功"
else
    log_error "Caddy 启动失败"
    caddy fmt --overwrite ${CADDY_DIR}/Caddyfile
    caddy validate --config ${CADDY_DIR}/Caddyfile
    exit 1
fi

# ============================================
# 完成信息
# ============================================
echo ""
log_info "=========================================="
log_info "    Aria2 + AriaNg + Caddy 部署完成!"
log_info "=========================================="
echo ""
log_info "访问地址：http://$(hostname -I | awk '{print $1}')"
echo ""
log_info "重要信息:"
log_info "  - Aria2 RPC 密钥：${RPC_SECRET}"
echo ""
log_info "配置文件位置:"
log_info "  - Aria2 配置：${ARIA2_DIR}/config/aria2.conf"
log_info "  - AriaNg 文件：${ARIANG_DIR}/"
log_info "  - Caddy 配置：${CADDY_DIR}/Caddyfile"
echo ""
log_info "下载文件保存位置：${DOWNLOAD_DIR}"
echo ""
log_info "服务管理命令:"
log_info "  systemctl status aria2   # 查看 Aria2 状态"
log_info "  systemctl status caddy   # 查看 Caddy 状态"
log_info "  journalctl -u aria2 -f   # 查看 Aria2 日志"
log_info "  journalctl -u caddy -f   # 查看 Caddy 日志"
echo ""

# 保存 RPC 密钥到文件
echo "${RPC_SECRET}" > ${ARIA2_DIR}/config/rpc-secret.txt
log_info "RPC 密钥已保存到：${ARIA2_DIR}/config/rpc-secret.txt"

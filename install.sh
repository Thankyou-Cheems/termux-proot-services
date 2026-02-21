#!/bin/bash
# Termux proot 业务管理套件 - 安装脚本
# 适用于 Debian proot 环境

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

echo "========================================"
echo "  Termux proot 业务管理套件 - 安装向导"
echo "========================================"
echo ""

# 检查是否在 proot 环境
if [ ! -f /etc/debian_version ]; then
    log_error "请在 Debian proot 环境中运行此脚本！"
    exit 1
fi

# 检查是否以 root 运行
if [ "$(id -u)" != "0" ]; then
    log_warn "建议以 root 身份运行此脚本"
fi

log_step "更新系统包..."
apt update -y
apt upgrade -y

log_step "安装基础依赖..."
apt install -y wget curl unzip git nodejs npm pnpm sqlite3 rsync

log_step "安装 PM2..."
npm install -g pm2

log_step "配置 SSH 服务..."
apt install -y openssh-server
mkdir -p /run/sshd
ssh-keygen -A
echo "Port 2222" >> /etc/ssh/sshd_config
echo "ListenAddress 0.0.0.0" >> /etc/ssh/sshd_config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

log_step "下载 ArchiSteamFarm..."
mkdir -p /opt/ASF
cd /opt/ASF
wget -q https://github.com/JustArchiNET/ArchiSteamFarm/releases/latest/download/ASF-linux-arm64.zip
unzip -q ASF-linux-arm64.zip
rm ASF-linux-arm64.zip
chmod +x ArchiSteamFarm

# 创建 ASF 配置
log_step "创建 ASF 配置..."
mkdir -p /opt/ASF/config
cat > /opt/ASF/config/ASF.json << 'EOF'
{
    "Headless": true,
    "IPCPassword": "CHANGE_THIS_PASSWORD",
    "SteamOwnerID": 0
}
EOF

log_step "下载 MCSManager..."
mkdir -p /opt/mcsmanager
cd /tmp
# 使用 Gitee 镜像源
LATEST_VERSION=$(curl -s https://gitee.com/api/v5/repos/mcsmanager/MCSManager/releases/latest | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4)
wget -q "https://gitee.com/mcsmanager/MCSManager/archive/refs/tags/${LATEST_VERSION}.zip" -O mcs.zip
unzip -q mcs.zip -d /tmp/mcs-new/

# 检测目录结构
if [ -d "/tmp/mcs-new/MCSManager-${LATEST_VERSION}/daemon" ]; then
    cp -rf /tmp/mcs-new/MCSManager-${LATEST_VERSION}/daemon/* /opt/mcsmanager/
    cp -rf /tmp/mcs-new/MCSManager-${LATEST_VERSION}/panel/* /opt/mcsmanager/web/ 2>/dev/null || \
    cp -rf /tmp/mcs-new/MCSManager-${LATEST_VERSION}/web/* /opt/mcsmanager/web/ 2>/dev/null || true
fi
rm -rf /tmp/mcs.zip /tmp/mcs-new/

log_step "安装 MCSManager 依赖..."
cd /opt/mcsmanager/daemon
pnpm install --production
cd /opt/mcsmanager/web
pnpm install --production

# 创建启动脚本
log_step "创建启动脚本..."
cat > /opt/mcsmanager/start-daemon.sh << 'EOF'
#!/bin/bash
cd /opt/mcsmanager/daemon
node --max-old-space-size=8192 --enable-source-maps app.js
EOF
chmod +x /opt/mcsmanager/start-daemon.sh

cat > /opt/mcsmanager/start-web.sh << 'EOF'
#!/bin/bash
cd /opt/mcsmanager/web
node --max-old-space-size=8192 --enable-source-maps app.js
EOF
chmod +x /opt/mcsmanager/start-web.sh

# 复制工具脚本
log_step "复制工具脚本..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -f "${SCRIPT_DIR}/update-all.sh" /opt/ 2>/dev/null || true
cp -f "${SCRIPT_DIR}/update-asf.sh" /opt/ 2>/dev/null || true
cp -f "${SCRIPT_DIR}/update-mcs.sh" /opt/ 2>/dev/null || true
cp -f "${SCRIPT_DIR}/rollback.sh" /opt/ 2>/dev/null || true
chmod +x /opt/*.sh 2>/dev/null || true

# 注册 PM2 服务
log_step "注册 PM2 服务..."
pm2 start /opt/ASF/ArchiSteamFarm --name asf
pm2 start /opt/mcsmanager/start-daemon.sh --name mcs-daemon
pm2 start /opt/mcsmanager/start-web.sh --name mcs-web
pm2 save --force

# 创建 proot 启动配置
log_step "创建 proot 启动配置..."
cat > /root/.bashrc.proot << 'EOF'
# proot 启动时自动执行
service ssh start
pm2 resurrect
EOF

# 添加到 .bashrc
if ! grep -q "pm2 resurrect" /root/.bashrc 2>/dev/null; then
    echo "" >> /root/.bashrc
    echo "# proot 服务自启" >> /root/.bashrc
    echo "service ssh start" >> /root/.bashrc
    echo "pm2 resurrect" >> /root/.bashrc
fi

# 启动 SSH
service ssh start

echo ""
echo "========================================"
echo "  ✅ 安装完成！"
echo "========================================"
echo ""
echo "📌 服务状态:"
pm2 list
echo ""
echo "🌐 访问地址:"
echo "  - MCSManager Web: http://localhost:23333"
echo "  - ASF IPC: http://localhost:1242"
echo ""
echo "🔐 SSH 连接:"
echo "  - 端口：2222"
echo "  - 用户：root"
echo "  - 密码：(在 Termux 中设置)"
echo ""
echo "📝 下一步:"
echo "  1. 修改 ASF 配置：/opt/ASF/config/ASF.json"
echo "  2. 添加 Steam 账号到 /opt/ASF/config/"
echo "  3. 运行 /opt/update-all.sh 更新到最新版本"
echo ""

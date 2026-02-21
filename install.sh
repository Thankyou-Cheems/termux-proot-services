#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f /etc/debian_version ]; then
  log_error "Please run this installer inside Debian proot."
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  log_error "Please run as root inside Debian proot."
  exit 1
fi

ensure_sshd_option() {
  local key="$1"
  local value="$2"
  local conf="/etc/ssh/sshd_config"
  if grep -qE "^[#[:space:]]*${key}[[:space:]]+" "$conf"; then
    sed -i "s|^[#[:space:]]*${key}[[:space:]].*|${key} ${value}|" "$conf"
  else
    echo "${key} ${value}" >> "$conf"
  fi
}

echo "========================================"
echo "termux-proot-services installer"
echo "========================================"

autoinstall_pkgs=(
  ca-certificates
  curl
  wget
  unzip
  git
  openssh-server
  nodejs
  npm
  python3
  aria2
  caddy
)

log_step "Installing base packages"
apt-get update -qq
apt-get install -y "${autoinstall_pkgs[@]}"

if ! command -v pnpm >/dev/null 2>&1; then
  log_step "Installing pnpm"
  npm install -g pnpm
fi

if ! command -v pm2 >/dev/null 2>&1; then
  log_step "Installing pm2"
  npm install -g pm2
fi

log_step "Configuring SSH (port 2222)"
mkdir -p /run/sshd
ssh-keygen -A >/dev/null 2>&1 || true
ensure_sshd_option "Port" "2222"
ensure_sshd_option "ListenAddress" "0.0.0.0"
ensure_sshd_option "PermitRootLogin" "yes"
service ssh restart >/dev/null 2>&1 || /etc/init.d/ssh restart >/dev/null 2>&1 || true

log_step "Deploying runtime scripts to /opt"
mkdir -p /opt/service /opt/caddy /opt/mcsmanager /opt/backups /opt/aria2/config /opt/aria2/data /opt/aria2/logs /opt/ariang

install -m 755 "${SCRIPT_DIR}/scripts/proot/update.sh" /opt/update.sh
install -m 755 "${SCRIPT_DIR}/scripts/proot/deploy-aria2.sh" /opt/deploy-aria2.sh
install -m 755 "${SCRIPT_DIR}/scripts/proot/rollback.sh" /opt/rollback.sh

install -m 755 "${SCRIPT_DIR}/scripts/proot/service/bootstrap.sh" /opt/service/bootstrap.sh
install -m 755 "${SCRIPT_DIR}/scripts/proot/service/update-asf-core.sh" /opt/service/update-asf-core.sh
install -m 755 "${SCRIPT_DIR}/scripts/proot/service/update-mcs-core.sh" /opt/service/update-mcs-core.sh

install -m 755 "${SCRIPT_DIR}/scripts/proot/mcsmanager/start-daemon.sh" /opt/mcsmanager/start-daemon.sh
install -m 755 "${SCRIPT_DIR}/scripts/proot/mcsmanager/start-web.sh" /opt/mcsmanager/start-web.sh

install -m 644 "${SCRIPT_DIR}/scripts/proot/caddy/Caddyfile" /opt/caddy/Caddyfile
install -m 644 "${SCRIPT_DIR}/scripts/proot/caddy/upstreams.env" /opt/caddy/upstreams.env

echo ""
log_info "Installer completed."
echo ""
echo "Next steps:"
echo "  1) Outer Termux: apply templates from templates/termux/"
echo "  2) In Debian: run /opt/service/bootstrap.sh"
echo "  3) Use /opt/update.sh (all|asf|mcs|aria2)"
echo ""

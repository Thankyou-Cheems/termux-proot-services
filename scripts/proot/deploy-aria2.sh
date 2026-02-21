#!/bin/bash
# Aria2 + AriaNg deployment for PRoot Debian (no systemd)
# Runtime model: PM2-managed processes

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

ARIA2_DIR="/opt/aria2"
ARIA2_CONF="${ARIA2_DIR}/config/aria2.conf"
ARIA2_SESSION="${ARIA2_DIR}/config/aria2.session"
ARIA2_SECRET_FILE="${ARIA2_DIR}/config/rpc-secret.txt"
ARIA2_START="${ARIA2_DIR}/start-aria2.sh"
ARIANG_HTTP_START="${ARIA2_DIR}/start-ariang-http.sh"
ARIANG_DIR="/opt/ariang"
CADDY_DIR="/opt/caddy"
CADDY_FILE="${CADDY_DIR}/Caddyfile"
CADDY_START="${CADDY_DIR}/start-caddy.sh"
CADDY_UPSTREAM_ENV="${CADDY_DIR}/upstreams.env"
DOWNLOAD_DIR="${ARIA2_DIR}/data"

FORCE_UI_UPDATE="${FORCE_UI_UPDATE:-0}"

ensure_command() {
  local cmd="$1"
  local pkg="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_info "Installing ${pkg}..."
    apt-get update -qq
    apt-get install -y "$pkg"
  fi
}

ensure_kv() {
  local key="$1"
  local value="$2"
  local conf="$3"
  if grep -qE "^[[:space:]]*${key}=" "$conf"; then
    sed -i "s|^[[:space:]]*${key}=.*|${key}=${value}|" "$conf"
  else
    printf '%s=%s\n' "$key" "$value" >> "$conf"
  fi
}

pm2_upsert() {
  local name="$1"
  local script="$2"
  if pm2 describe "$name" >/dev/null 2>&1; then
    pm2 restart "$name" --update-env >/dev/null
  else
    pm2 start "$script" --name "$name" >/dev/null
  fi
}

log_step "Checking base dependencies"
ensure_command curl curl
ensure_command unzip unzip
ensure_command openssl openssl
ensure_command aria2c aria2

if ! command -v pm2 >/dev/null 2>&1; then
  log_error "pm2 is required but not found"
  exit 1
fi

log_step "Preparing directories"
mkdir -p "${ARIA2_DIR}/config" "${ARIA2_DIR}/data" "${ARIA2_DIR}/logs" "${ARIANG_DIR}" "${CADDY_DIR}"
touch "${ARIA2_SESSION}"

if [ -s "${ARIA2_SECRET_FILE}" ]; then
  RPC_SECRET=$(cat "${ARIA2_SECRET_FILE}")
else
  RPC_SECRET=$(openssl rand -hex 16)
fi

echo "${RPC_SECRET}" > "${ARIA2_SECRET_FILE}"
chmod 600 "${ARIA2_SECRET_FILE}"

if [ ! -f "${CADDY_UPSTREAM_ENV}" ]; then
  cat > "${CADDY_UPSTREAM_ENV}" <<'ENV'
# Caddy reverse-proxy upstreams
# Update ASF_UPSTREAM when phone LAN IP changes.
ASF_UPSTREAM=10.126.126.4:1242
ENV
fi

log_step "Configuring aria2"
if [ ! -f "${ARIA2_CONF}" ]; then
  cat > "${ARIA2_CONF}" <<CFG
# Aria2 runtime config (managed by deploy-aria2.sh)
dir=${DOWNLOAD_DIR}
log=${ARIA2_DIR}/logs/aria2.log
log-level=warn
input-file=${ARIA2_SESSION}
save-session=${ARIA2_SESSION}
save-session-interval=60
continue=true
file-allocation=none
enable-rpc=true
rpc-listen-all=true
rpc-listen-port=6800
rpc-secret=${RPC_SECRET}
rpc-allow-origin-all=true
max-concurrent-downloads=5
max-connection-per-server=16
min-split-size=10M
enable-dht=true
enable-dht6=true
dht-listen-port=6881-6999
listen-port=6881-6999
enable-peer-exchange=true
max-overall-download-limit=0
max-overall-upload-limit=0
disable-ipv6=false
CFG
fi

# Force critical values for remote usage consistency.
ensure_kv "dir" "${DOWNLOAD_DIR}" "${ARIA2_CONF}"
ensure_kv "log" "${ARIA2_DIR}/logs/aria2.log" "${ARIA2_CONF}"
ensure_kv "input-file" "${ARIA2_SESSION}" "${ARIA2_CONF}"
ensure_kv "save-session" "${ARIA2_SESSION}" "${ARIA2_CONF}"
ensure_kv "enable-rpc" "true" "${ARIA2_CONF}"
ensure_kv "rpc-listen-all" "true" "${ARIA2_CONF}"
ensure_kv "rpc-listen-port" "6800" "${ARIA2_CONF}"
ensure_kv "rpc-secret" "${RPC_SECRET}" "${ARIA2_CONF}"
ensure_kv "rpc-allow-origin-all" "true" "${ARIA2_CONF}"

log_step "Preparing AriaNg web files"
need_download=0
if [ ! -s "${ARIANG_DIR}/index.html" ]; then
  need_download=1
fi
if [ "${FORCE_UI_UPDATE}" = "1" ]; then
  need_download=1
fi

if [ "${need_download}" -eq 1 ]; then
  TMP_DIR=$(mktemp -d)
  cleanup() {
    rm -rf "${TMP_DIR}"
  }
  trap cleanup EXIT

  ARIANG_TAG=$(curl -fsSL https://api.github.com/repos/mayswind/AriaNg/releases/latest | grep -m1 '"tag_name"' | cut -d'"' -f4 || true)
  if [ -z "${ARIANG_TAG}" ]; then
    ARIANG_TAG="1.3.9"
    log_warn "Could not query latest AriaNg tag, fallback to ${ARIANG_TAG}"
  fi

  ZIP_URL="https://github.com/mayswind/AriaNg/releases/download/${ARIANG_TAG}/AriaNg-${ARIANG_TAG}-AllInOne.zip"
  if curl -fsSL "${ZIP_URL}" -o "${TMP_DIR}/ariang.zip"; then
    unzip -q -o "${TMP_DIR}/ariang.zip" -d "${ARIANG_DIR}"
    log_info "AriaNg downloaded (${ARIANG_TAG})"
  else
    log_warn "AriaNg zip download failed, fallback to jsDelivr"
    curl -fsSL "https://cdn.jsdelivr.net/gh/mayswind/AriaNg@${ARIANG_TAG}/index.html" -o "${ARIANG_DIR}/index.html"
  fi
fi

log_step "Writing runtime scripts"
cat > "${ARIA2_START}" <<'SH'
#!/bin/bash
set -e
exec aria2c --conf-path=/opt/aria2/config/aria2.conf --daemon=false
SH
chmod +x "${ARIA2_START}"

cat > "${ARIANG_HTTP_START}" <<'SH'
#!/bin/bash
set -e
cd /opt/ariang || exit 1
exec python3 -m http.server 6801 --bind 0.0.0.0
SH
chmod +x "${ARIANG_HTTP_START}"

cat > "${CADDY_START}" <<'SH'
#!/bin/bash
set -e

if [ -f /opt/caddy/upstreams.env ]; then
  set -a
  . /opt/caddy/upstreams.env
  set +a
fi

exec caddy run --config /opt/caddy/Caddyfile --adapter caddyfile
SH
chmod +x "${CADDY_START}"

log_step "Starting PM2 services"
pm2_upsert "aria2" "${ARIA2_START}"

UI_MODE="python"
UI_URL_PORT="6801"

if command -v caddy >/dev/null 2>&1; then
  if [ ! -f "${CADDY_FILE}" ]; then
    cat > "${CADDY_FILE}" <<'CADDY'
:8080 {
  route {
    redir /mcs /mcs/ 308

    redir /asf /asf/ 308

    handle /jsonrpc* {
      reverse_proxy localhost:6800
    }
    handle /ws {
      reverse_proxy localhost:6800
    }

    handle /mcs/* {
      uri strip_prefix /mcs
      reverse_proxy localhost:23333
    }

    handle /asf/* {
      uri strip_prefix /asf
      reverse_proxy {$ASF_UPSTREAM:10.126.126.4:1242}
    }

    root * /opt/ariang
    file_server
  }
}
CADDY
  fi

  if caddy validate --config "${CADDY_FILE}" >/dev/null 2>&1; then
    pm2_upsert "caddy" "${CADDY_START}"
    pm2 delete ariang-web >/dev/null 2>&1 || true
    UI_MODE="caddy"
    UI_URL_PORT="8080"
  else
    log_warn "Existing Caddyfile invalid; fallback to python web server on 6801"
    pm2 delete caddy >/dev/null 2>&1 || true
    pm2_upsert "ariang-web" "${ARIANG_HTTP_START}"
  fi
else
  log_warn "caddy not found; using python web server on 6801"
  pm2 delete caddy >/dev/null 2>&1 || true
  pm2_upsert "ariang-web" "${ARIANG_HTTP_START}"
fi

pm2 save --force >/dev/null

HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
if [ -z "${HOST_IP}" ]; then
  HOST_IP="<phone-ip>"
fi

echo ""
log_info "Aria2 deployment completed (PM2 mode)"
log_info "RPC secret: ${RPC_SECRET}"
log_info "RPC endpoint (direct): http://${HOST_IP}:6800/jsonrpc"
if [ "${UI_MODE}" = "caddy" ]; then
  log_info "AriaNg URL: http://${HOST_IP}:${UI_URL_PORT}"
  log_info "Aria2 RPC via proxy: http://${HOST_IP}:${UI_URL_PORT}/jsonrpc"
else
  log_info "AriaNg URL: http://${HOST_IP}:${UI_URL_PORT}"
  log_info "Set AriaNg RPC manually to: http://${HOST_IP}:6800/jsonrpc"
fi
log_info "ASF upstream source: ${CADDY_UPSTREAM_ENV}"

echo ""
pm2 ls

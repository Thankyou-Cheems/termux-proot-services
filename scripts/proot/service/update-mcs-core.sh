#!/bin/bash
set -euo pipefail

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/backups/${DATE}/mcsmanager"
mkdir -p "${BACKUP_DIR}/daemon" "${BACKUP_DIR}/web"

echo "[INFO] Backing up MCSManager config to ${BACKUP_DIR}"
for d in Config InstanceConfig InstanceData TaskConfig; do
  cp -a "/opt/mcsmanager/daemon/data/${d}" "${BACKUP_DIR}/daemon/" 2>/dev/null || true
done
for d in SystemConfig User RemoteServiceConfig operation_logs; do
  cp -a "/opt/mcsmanager/web/data/${d}" "${BACKUP_DIR}/web/" 2>/dev/null || true
done
cp -a /opt/mcsmanager/web/data/current-version.txt "${BACKUP_DIR}/web/" 2>/dev/null || true
cp -a /opt/mcsmanager/web/data/market_cache.json "${BACKUP_DIR}/web/" 2>/dev/null || true

CURRENT_WEB_VERSION=$(grep -m1 '"version"' /opt/mcsmanager/web/package.json | cut -d'"' -f4 || true)
LATEST_TAG=$(curl -fsSL https://api.github.com/repos/MCSManager/MCSManager/releases/latest | grep -m1 '"tag_name"' | cut -d'"' -f4 || true)

if [ -z "${LATEST_TAG}" ]; then
  echo "[ERROR] Unable to fetch MCSManager latest release tag"
  exit 1
fi

echo "[INFO] Current MCS Web version: ${CURRENT_WEB_VERSION:-unknown}"
echo "[INFO] Target MCS tag: ${LATEST_TAG}"

TMP_DIR=$(mktemp -d)
SERVICES_STOPPED=0

cleanup() {
  rm -rf "${TMP_DIR}"
}

restore_on_error() {
  if [ "${SERVICES_STOPPED}" -eq 1 ]; then
    pm2 start mcs-daemon >/dev/null 2>&1 || true
    pm2 start mcs-web >/dev/null 2>&1 || true
  fi
  echo "[ERROR] MCSManager update failed"
}

trap cleanup EXIT
trap restore_on_error ERR

curl -fsSL "https://github.com/MCSManager/MCSManager/archive/refs/tags/${LATEST_TAG}.zip" -o "${TMP_DIR}/mcs.zip"
unzip -q "${TMP_DIR}/mcs.zip" -d "${TMP_DIR}/src"
SRC_DIR=$(find "${TMP_DIR}/src" -mindepth 1 -maxdepth 1 -type d | head -1)

if [ -z "${SRC_DIR}" ] || [ ! -d "${SRC_DIR}/daemon" ]; then
  echo "[ERROR] Invalid MCSManager package layout"
  exit 1
fi

if [ -d "${SRC_DIR}/web" ]; then
  WEB_SRC="${SRC_DIR}/web"
elif [ -d "${SRC_DIR}/panel" ]; then
  WEB_SRC="${SRC_DIR}/panel"
else
  echo "[ERROR] Cannot find web/panel directory in release package"
  exit 1
fi

pm2 stop mcs-daemon >/dev/null 2>&1 || true
pm2 stop mcs-web >/dev/null 2>&1 || true
SERVICES_STOPPED=1

# Overlay code, but preserve runtime data/logs/node_modules.
tar -C "${SRC_DIR}/daemon" --exclude='data' --exclude='logs' --exclude='node_modules' -cf - . | tar -C /opt/mcsmanager/daemon -xf -
tar -C "${WEB_SRC}" --exclude='data' --exclude='logs' --exclude='node_modules' -cf - . | tar -C /opt/mcsmanager/web -xf -

if command -v pnpm >/dev/null 2>&1; then
  (cd /opt/mcsmanager/daemon && pnpm install --prod --frozen-lockfile=false)
  (cd /opt/mcsmanager/web && pnpm install --prod --frozen-lockfile=false)
else
  (cd /opt/mcsmanager/daemon && npm install --omit=dev)
  (cd /opt/mcsmanager/web && npm install --omit=dev)
fi

pm2 start mcs-daemon >/dev/null 2>&1 || true
pm2 start mcs-web >/dev/null 2>&1 || true
SERVICES_STOPPED=0
pm2 save --force >/dev/null 2>&1 || true
trap - ERR

echo "[INFO] MCSManager update done. Backup: ${BACKUP_DIR}"

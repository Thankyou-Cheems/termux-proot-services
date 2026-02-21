#!/bin/bash
set -euo pipefail

TARGET_BACKUP="${1:-}"

if [ -n "${TARGET_BACKUP}" ]; then
  BACKUP_DIR="${TARGET_BACKUP%/}"
else
  BACKUP_DIR=$(ls -1dt /opt/backups/* 2>/dev/null | head -1 || true)
fi

if [ -z "${BACKUP_DIR}" ] || [ ! -d "${BACKUP_DIR}" ]; then
  echo "[ERROR] No backup directory found"
  echo "Usage: /opt/rollback.sh /opt/backups/<timestamp>"
  exit 1
fi

echo "[INFO] Restoring from: ${BACKUP_DIR}"

pm2 stop asf >/dev/null 2>&1 || true
pm2 stop mcs-daemon >/dev/null 2>&1 || true
pm2 stop mcs-web >/dev/null 2>&1 || true

if [ -d "${BACKUP_DIR}/asf/config" ]; then
  mkdir -p /opt/ASF/config
  cp -a "${BACKUP_DIR}/asf/config/." /opt/ASF/config/
fi
cp -a "${BACKUP_DIR}/asf/ASF.json" /opt/ASF/ 2>/dev/null || true
cp -a "${BACKUP_DIR}/asf/IPC.config" /opt/ASF/ 2>/dev/null || true

for d in Config InstanceConfig InstanceData TaskConfig; do
  if [ -d "${BACKUP_DIR}/mcsmanager/daemon/${d}" ]; then
    rm -rf "/opt/mcsmanager/daemon/data/${d}"
    cp -a "${BACKUP_DIR}/mcsmanager/daemon/${d}" /opt/mcsmanager/daemon/data/
  fi
done

for d in SystemConfig User RemoteServiceConfig operation_logs; do
  if [ -d "${BACKUP_DIR}/mcsmanager/web/${d}" ]; then
    rm -rf "/opt/mcsmanager/web/data/${d}"
    cp -a "${BACKUP_DIR}/mcsmanager/web/${d}" /opt/mcsmanager/web/data/
  fi
done
cp -a "${BACKUP_DIR}/mcsmanager/web/current-version.txt" /opt/mcsmanager/web/data/ 2>/dev/null || true
cp -a "${BACKUP_DIR}/mcsmanager/web/market_cache.json" /opt/mcsmanager/web/data/ 2>/dev/null || true

pm2 start asf >/dev/null 2>&1 || true
pm2 start mcs-daemon >/dev/null 2>&1 || true
pm2 start mcs-web >/dev/null 2>&1 || true
pm2 save --force >/dev/null 2>&1 || true

echo "[INFO] Rollback completed."

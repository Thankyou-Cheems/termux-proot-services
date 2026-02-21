#!/bin/bash
set -euo pipefail

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/backups/${DATE}/asf"
mkdir -p "${BACKUP_DIR}/config"

echo "[INFO] Backing up ASF config to ${BACKUP_DIR}"
cp -a /opt/ASF/config/. "${BACKUP_DIR}/config/" 2>/dev/null || true
cp -a /opt/ASF/ASF.json "${BACKUP_DIR}/" 2>/dev/null || true
cp -a /opt/ASF/IPC.config "${BACKUP_DIR}/" 2>/dev/null || true

CURRENT_TAG=$(grep -m1 -o 'V[0-9.]*' /opt/ASF/log.txt 2>/dev/null | tr -d 'V' || true)
LATEST_TAG=$(curl -fsSL https://api.github.com/repos/JustArchiNET/ArchiSteamFarm/releases/latest | grep -m1 '"tag_name"' | cut -d'"' -f4 || true)

if [ -z "${LATEST_TAG}" ]; then
  echo "[ERROR] Unable to fetch ASF latest release tag"
  exit 1
fi

echo "[INFO] Current ASF version: ${CURRENT_TAG:-unknown}"
echo "[INFO] Target ASF version: ${LATEST_TAG}"

TMP_DIR=$(mktemp -d)
SERVICES_STOPPED=0

cleanup() {
  rm -rf "${TMP_DIR}"
}

restore_on_error() {
  if [ "${SERVICES_STOPPED}" -eq 1 ]; then
    pm2 start asf >/dev/null 2>&1 || true
  fi
  echo "[ERROR] ASF update failed"
}

trap cleanup EXIT
trap restore_on_error ERR

wget -q "https://github.com/JustArchiNET/ArchiSteamFarm/releases/download/${LATEST_TAG}/ASF-linux-arm64.zip" -O "${TMP_DIR}/asf.zip"
unzip -q "${TMP_DIR}/asf.zip" -d "${TMP_DIR}/new"

pm2 stop asf >/dev/null 2>&1 || true
SERVICES_STOPPED=1

# Overlay new files; then restore user config backup.
tar -C "${TMP_DIR}/new" -cf - . | tar -C /opt/ASF -xf -
cp -a "${BACKUP_DIR}/config/." /opt/ASF/config/ 2>/dev/null || true
cp -a "${BACKUP_DIR}/ASF.json" /opt/ASF/ 2>/dev/null || true
cp -a "${BACKUP_DIR}/IPC.config" /opt/ASF/ 2>/dev/null || true

pm2 start asf >/dev/null 2>&1 || true
SERVICES_STOPPED=0
pm2 save --force >/dev/null 2>&1 || true
trap - ERR

echo "[INFO] ASF update done. Backup: ${BACKUP_DIR}"

#!/bin/bash
set -euo pipefail

TARGET="${1:-all}"

usage() {
  cat <<USAGE
Usage: /opt/update.sh [target]

Targets:
  all      Update ASF + MCSManager + Aria2 stack (default)
  asf      Update ASF only
  mcs      Update MCSManager only
  aria2    Re-deploy/update Aria2 + AriaNg + Caddy (PM2 mode)
  help     Show this help
USAGE
}

run_asf() {
  /opt/service/update-asf-core.sh
}

run_mcs() {
  /opt/service/update-mcs-core.sh
}

run_aria2() {
  /opt/deploy-aria2.sh
}

case "${TARGET}" in
  all)
    run_asf
    run_mcs
    run_aria2
    echo "[INFO] Unified update completed: all"
    ;;
  asf)
    run_asf
    ;;
  mcs|mcsmanager)
    run_mcs
    ;;
  aria2|aria)
    run_aria2
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "[ERROR] Unknown target: ${TARGET}" >&2
    usage >&2
    exit 1
    ;;
esac

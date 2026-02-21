#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

exec proot-distro login debian -- bash -lc '
  /opt/service/bootstrap.sh
  exec bash
'

#!/bin/bash
set -euo pipefail

# Ensure Debian SSH endpoint is up (port 2222 inside proot).
if ! ss -tnlp 2>/dev/null | grep -q ':2222 '; then
  service ssh start >/dev/null 2>&1 || /etc/init.d/ssh start >/dev/null 2>&1 || true
fi

# Restore PM2 managed services if a saved process list exists.
if command -v pm2 >/dev/null 2>&1; then
  pm2 resurrect >/dev/null 2>&1 || true
fi

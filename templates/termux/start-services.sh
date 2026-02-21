#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Must run in the outer Termux user namespace.
if [ "$(id -u)" -eq 0 ]; then
  echo "Skip: this script must run in outer Termux (non-root)."
  exit 0
fi

# Keep device awake to reduce background kill risk.
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock >/dev/null 2>&1 || true
fi

# Ensure outer SSH endpoint is reachable.
if ! pgrep -f "[s]shd.*-p 8022" >/dev/null 2>&1; then
  /data/data/com.termux/files/usr/bin/sshd -p 8022 >/dev/null 2>&1 || true
fi

# Ensure Debian tmux anchor session exists.
if tmux has-session -t debian 2>/dev/null; then
  echo "Debian session already running."
  exit 0
fi

setsid tmux new-session -d -s debian "$HOME/proot-debian-bootstrap.sh" >/dev/null 2>&1

echo "Debian session started."

#!/data/data/com.termux/files/usr/bin/bash

# Must run in outer Termux user context, not a nested proot SSH view.
if [ "$(id -u)" -eq 0 ]; then
    echo "Skip: running as uid 0 (likely nested PRoot SSH view)."
    exit 0
fi

# Keep Android from suspending startup work.
termux-wake-lock 2>/dev/null || true

# Ensure outer SSH listener is available for reconnect.
/data/data/com.termux/files/usr/bin/sshd -p 8022 >/dev/null 2>&1 || true

# Idempotent: skip if already running.
if tmux has-session -t debian 2>/dev/null; then
    echo "Debian already running."
    exit 0
fi

# Detach from current terminal so the session survives SSH disconnect.
setsid tmux new-session -d -s debian '
  proot-distro login debian -- bash -lc "
    service ssh start
    pm2 resurrect
    exec bash
  "
' >/dev/null 2>&1

echo "Debian started."

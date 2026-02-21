# termux-proot-services

在 Android Termux + Debian proot-distro 场景下，提供可恢复、可维护、可审计的服务运维脚本与模板。

## Current Architecture

- Layer 1: Outer Termux (`u0_a*`)
  - Entry script: `~/start-services.sh`
  - Boot hook: `~/.termux/boot/00-start-services.sh`
  - Responsibilities: wake lock, outer SSH (`8022`), tmux session anchor.
- Layer 2: Debian proot (`root`)
  - Bootstrap: `/opt/service/bootstrap.sh`
  - Responsibilities: internal SSH (`2222`), `pm2 resurrect`, service runtime.
- Process manager: `pm2`
  - Typical managed processes: `asf`, `mcs-daemon`, `mcs-web`, `aria2`, `caddy`.

## Repository Layout

```text
.
├── scripts/
│   └── proot/
│       ├── update.sh
│       ├── deploy-aria2.sh
│       ├── rollback.sh
│       ├── service/
│       │   ├── bootstrap.sh
│       │   ├── update-asf-core.sh
│       │   └── update-mcs-core.sh
│       ├── caddy/
│       │   ├── Caddyfile
│       │   └── upstreams.env
│       └── mcsmanager/
│           ├── start-daemon.sh
│           └── start-web.sh
├── templates/
│   └── termux/
│       ├── start-services.sh
│       ├── proot-debian-bootstrap.sh
│       ├── bashrc.snippet
│       └── boot/
│           └── 00-start-services.sh
├── docs/
│   ├── QUICKSTART.md
│   └── ARCHITECTURE.md
└── install.sh
```

## Operational Commands

- Unified update entry: `/opt/update.sh`
- Targets:
  - `/opt/update.sh all`
  - `/opt/update.sh asf`
  - `/opt/update.sh mcs`
  - `/opt/update.sh aria2`
- Rollback: `/opt/rollback.sh` or `/opt/rollback.sh /opt/backups/<timestamp>`

## Caddy Routing Notes

- Caddy listens on `:8080`.
- `/jsonrpc` and `/ws` proxy to aria2 (`localhost:6800`).
- `/mcs` and `/asf` are normalized to trailing slash (`308`).
- ASF upstream is configurable via `/opt/caddy/upstreams.env`:

```bash
ASF_UPSTREAM=<phone-lan-ip>:1242
```

## SSH Topology (Windows)

```sshconfig
Host termux
    HostName <PHONE_IP>
    Port 8022
    User u0_a6

Host proot-debian
    HostName <PHONE_IP>
    Port 2222
    User root
```

Verification:

```powershell
ssh termux "whoami; id -u; grep TracerPid /proc/self/status"
ssh proot-debian "whoami; id -u"
```

Expected:

- `termux`: `u0_a*`, uid `100xx`, `TracerPid: 0`
- `proot-debian`: `root`, uid `0`

## References

- Termux: https://termux.dev/
- proot-distro: https://github.com/termux/proot-distro
- ArchiSteamFarm: https://github.com/JustArchiNET/ArchiSteamFarm
- MCSManager: https://github.com/MCSManager/MCSManager
- Aria2: https://github.com/aria2/aria2
- AriaNg: https://github.com/mayswind/AriaNg
- Caddy: https://github.com/caddyserver/caddy

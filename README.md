# Termux PRoot Services

在 Android Termux + Debian proot-distro 环境下，提供可长期维护的服务部署与运维方案。

## Scope

本仓库覆盖以下目标：

- 统一部署 ArchiSteamFarm、MCSManager、Aria2 + AriaNg + Caddy。
- 通过多层 SSH 别名区分 Termux 外层与 Debian proot。
- 支持开机自启动、会话保活、断线可恢复。
- 提供更新、回滚、故障排查、恢复部署实践。

## Services And Ports

| Service | Purpose | Default Ports |
|---|---|---|
| ArchiSteamFarm | Steam automation | IPC 1242 |
| MCSManager | Minecraft panel and daemon | Web 23333, Daemon 24444 |
| Aria2 + AriaNg + Caddy | Download service and web UI | Web 80, RPC 6800 |
| SSH (outer Termux) | Remote entry for Termux user | 8022 |
| SSH (Debian proot) | Remote entry for proot root | 2222 |

## Architecture

- Layer 1: **Outer Termux** (`u0_a*` app user)
  - Responsible for boot orchestration, outer SSH, and entry scripts.
- Layer 2: **Debian proot** (`root` inside proot view)
  - Runs business services and internal SSH.

Recommended access split:

- `ssh termux` -> outer Termux (`u0_a*`, port `8022`)
- `ssh proot-debian` -> Debian proot (`root`, port `2222`)

## SSH Topology (Windows Client)

`~/.ssh/config` example:

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

## Boot And Session Persistence

### 1) Outer launcher script

`~/start-debian-tmux.sh` responsibilities:

- Acquire wake lock (`termux-wake-lock`).
- Ensure outer SSH (`sshd -p 8022`) is available.
- Skip if tmux session already exists.
- Start `tmux` session (`debian`) with `setsid` to survive SSH disconnect.
- Inside proot: run `service ssh start`, `pm2 resurrect`, then keep shell alive.

### 2) Termux:Boot entry

`~/.termux/boot/start-debian.sh`:

```bash
#!/data/data/com.termux/files/usr/bin/bash
sleep 5
~/start-debian-tmux.sh
```

### 3) Interactive shell auto-start

`~/.bashrc`:

```bash
case $- in
  *i*) ~/start-debian-tmux.sh ;;
esac
```

This avoids triggering startup during non-interactive SSH command execution.

### Required apps/packages

- App: `Termux:Boot`
- App: `Termux:API`
- Package: `termux-api`

## Remote Stability Strategy

- Keep business runtime in tmux session `debian`.
- Use PM2 for service process persistence (`pm2 save`, `pm2 resurrect`).
- Separate outer SSH and proot SSH ports to reduce coupling.
- Use idempotent startup scripts (safe to run repeatedly).

Common operations:

```bash
ssh termux
~/start-debian-tmux.sh
tmux ls

ssh proot-debian
pm2 list
pm2 logs
```

## Failure Patterns And Fixes

### Symptom: `ssh termux` enters `root` unexpectedly

Cause: connected to a traced/nested SSH context, not true outer Termux.

Check:

```bash
whoami
id -u
grep TracerPid /proc/self/status
```

Fix target state:

- `whoami` is `u0_a*`
- `id -u` is `100xx`
- `TracerPid` is `0`

### Symptom: `Connection closed by <ip> port 8022`

Cause: outer Termux SSH listener not running or unhealthy.

Actions:

- Start/restart outer `sshd` in outer Termux context.
- Re-verify with `ssh termux "whoami; id -u"`.

### Symptom: `proot-distro should not be executed under PRoot`

Cause: trying to run `proot-distro login` from an already nested/proot context.

Action:

- Run launcher from outer Termux user context (`u0_a*`), not nested root view.

## Repository Usage

### Install

```bash
proot-distro login debian
git clone https://github.com/Thankyou-Cheems/termux-proot-services.git
cd termux-proot-services
./install.sh
```

### Update and rollback

```bash
/opt/update-all.sh
/opt/update-asf.sh
/opt/update-mcs.sh
/opt/deploy-aria2.sh
/opt/rollback.sh
```

## Key Management Policy

Recommended model:

- Public repo operations: one account key (`github-global`).
- Sensitive/private repo operations: per-repo deploy key (`github-recovery-kit`).

Example `/root/.ssh/config`:

```sshconfig
Host github-global
  HostName github.com
  User git
  IdentityFile /root/.ssh/github_key
  IdentitiesOnly yes

Host github-recovery-kit
  HostName github.com
  User git
  IdentityFile /root/.ssh/id_ed25519_termux_recovery
  IdentitiesOnly yes
```

Why:

- Reduces blast radius if one key is compromised.
- Keeps automation repository-scoped.
- Avoids mixing public and private write credentials.

## Directory Layout

```text
/opt/
├── ASF/
├── mcsmanager/
├── aria2/
├── ariang/
├── caddy/
├── backups/
├── update-all.sh
├── update-asf.sh
├── update-mcs.sh
├── deploy-aria2.sh
└── rollback.sh
```

## References

- Termux: https://termux.dev/
- proot-distro: https://github.com/termux/proot-distro
- ArchiSteamFarm: https://github.com/JustArchiNET/ArchiSteamFarm
- MCSManager: https://github.com/MCSManager/MCSManager
- Aria2: https://github.com/aria2/aria2
- AriaNg: https://github.com/mayswind/AriaNg
- Caddy: https://github.com/caddyserver/caddy

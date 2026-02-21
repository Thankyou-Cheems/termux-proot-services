# Architecture

## Runtime Layers

1. Outer Termux (`u0_a*`)
- Owns Android-side process lifecycle.
- Runs `sshd` on `8022`.
- Creates/keeps tmux session `debian`.

2. Debian proot (`root`)
- Runs service workloads.
- Runs `sshd` on `2222`.
- Uses PM2 as process supervisor.

## Startup Flow

1. Device boot -> `~/.termux/boot/00-start-services.sh`
2. Calls `~/start-services.sh`
3. Ensures outer `sshd:8022`
4. Creates tmux session `debian` if absent
5. tmux runs `~/proot-debian-bootstrap.sh`
6. `proot-distro login debian` -> `/opt/service/bootstrap.sh`
7. bootstrap starts SSH in proot and runs `pm2 resurrect`

## Update Flow

Single entry: `/opt/update.sh`

- `all`: ASF + MCS + aria2 stack
- `asf`: ASF only
- `mcs`: MCSManager only
- `aria2`: Aria2/AriaNg/Caddy only

Implementation split:

- `/opt/service/update-asf-core.sh`
- `/opt/service/update-mcs-core.sh`
- `/opt/deploy-aria2.sh`

## Reverse Proxy Flow (Caddy)

Entry port: `8080`

- `/jsonrpc`, `/ws` -> aria2 (`localhost:6800`)
- `/mcs/*` -> MCS panel (`localhost:23333`)
- `/asf/*` -> ASF web (`$ASF_UPSTREAM`, default `10.126.126.4:1242`)
- `/` -> AriaNg static site (`/opt/ariang`)

`/mcs` and `/asf` are normalized to trailing slash via `308` redirects.

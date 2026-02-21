# Quickstart

## 1. Prerequisites

On Android:

- Install `Termux` (F-Droid recommended)
- Install `Termux:Boot`
- Install `Termux:API`

In outer Termux:

```bash
pkg update -y
pkg upgrade -y
pkg install -y proot-distro termux-api openssh tmux
```

## 2. Debian proot setup

```bash
proot-distro install debian
proot-distro login debian
```

In Debian:

```bash
git clone https://github.com/Thankyou-Cheems/termux-proot-services.git
cd termux-proot-services
chmod +x install.sh
./install.sh
```

This deploys runtime scripts to `/opt`:

- `/opt/update.sh`
- `/opt/deploy-aria2.sh`
- `/opt/rollback.sh`
- `/opt/service/*`

## 3. Outer Termux startup templates

In outer Termux (not inside proot):

```bash
cd ~
git clone https://github.com/Thankyou-Cheems/termux-proot-services.git
cd termux-proot-services

cp templates/termux/start-services.sh ~/start-services.sh
cp templates/termux/proot-debian-bootstrap.sh ~/proot-debian-bootstrap.sh
chmod +x ~/start-services.sh ~/proot-debian-bootstrap.sh

mkdir -p ~/.termux/boot
cp templates/termux/boot/00-start-services.sh ~/.termux/boot/00-start-services.sh
chmod +x ~/.termux/boot/00-start-services.sh

if ! grep -q 'start-services.sh' ~/.bashrc 2>/dev/null; then
  cat templates/termux/bashrc.snippet >> ~/.bashrc
fi
```

## 4. Windows SSH aliases

`C:\Users\<you>\.ssh\config`:

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

## 5. Update and rollback

In Debian proot:

```bash
/opt/update.sh all
/opt/update.sh asf
/opt/update.sh mcs
/opt/update.sh aria2

/opt/rollback.sh
```

## 6. Aria2/Caddy notes

- Aria2 + AriaNg + Caddy deployment: `/opt/deploy-aria2.sh`
- Caddy config: `/opt/caddy/Caddyfile`
- ASF upstream setting: `/opt/caddy/upstreams.env`

If phone LAN IP changes, update:

```bash
ASF_UPSTREAM=<new_phone_ip>:1242
pm2 restart caddy --update-env
```

# 快速入门指南

## 1. 准备工作

### 安装 Termux

从 F-Droid 下载 Termux（推荐）或 GitHub Releases：
- [F-Droid](https://f-droid.org/packages/com.termux/)
- [GitHub](https://github.com/termux/termux-app/releases)

### 基础设置

```bash
# 更新包
pkg update && pkg upgrade

# 安装 proot-distro
pkg install proot-distro

# 安装 Debian
proot-distro install debian
```

## 2. 安装业务套件（Debian proot）

```bash
# 进入 proot 环境
proot-distro login debian

# 克隆仓库
git clone https://github.com/Thankyou-Cheems/termux-proot-services.git
cd termux-proot-services

# 运行安装脚本
chmod +x install.sh
./install.sh
```

## 3. 配置服务

### ASF 配置

```bash
nano /opt/ASF/config/ASF.json
```

示例：

```json
{
  "IPCPassword": "你的安全密码",
  "SteamOwnerID": 你的 SteamID64
}
```

### MCSManager 配置

首次访问 Web 面板按引导完成初始化。

## 4. 启动与检查（proot 内）

```bash
pm2 list
pm2 logs
pm2 restart all
```

## 5. 配置外层 Termux 开机自启与会话保活

在 **Termux 外层**（不是 proot）执行：

```bash
# 克隆同一个仓库到外层 Termux
cd ~
git clone https://github.com/Thankyou-Cheems/termux-proot-services.git
cd termux-proot-services

# 写入启动脚本
cp templates/termux/start-debian-tmux.sh ~/start-debian-tmux.sh
chmod +x ~/start-debian-tmux.sh

# 写入 Termux:Boot 脚本
mkdir -p ~/.termux/boot
cp templates/termux/boot/start-debian.sh ~/.termux/boot/start-debian.sh
chmod +x ~/.termux/boot/start-debian.sh

# 追加交互 shell 自动启动片段（避免非交互命令触发）
if ! grep -q "start-debian-tmux.sh" ~/.bashrc 2>/dev/null; then
  cat templates/termux/bashrc.snippet >> ~/.bashrc
fi
```

依赖要求：

- 安装 App: `Termux:Boot`
- 安装 App: `Termux:API`
- 安装包: `termux-api`

## 6. Windows 侧 SSH 别名（推荐）

`C:\Users\<你>\.ssh\config`：

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

验证：

```powershell
ssh termux "whoami; id -u; grep TracerPid /proc/self/status"
ssh proot-debian "whoami; id -u"
```

预期：

- `termux` 为 `u0_a*` + uid `100xx`
- `proot-debian` 为 `root` + uid `0`

## 7. 可选：部署 Aria2 + AriaNg + Caddy

```bash
# 在 Debian proot 中执行
/opt/deploy-aria2.sh
```

## 常见问题

### Q: `ssh termux` 进去是 root，为什么？
A: 你连接到的是嵌套/被追踪上下文，不是外层 Termux。应确保 `termux` 别名连的是 `8022` 外层监听，并验证 `TracerPid: 0`。

### Q: 外层 8022 连接后立即断开
A: 先在外层执行 `~/start-debian-tmux.sh`，它会尝试拉起外层 `sshd -p 8022`。

### Q: 更新失败怎么办
A: 运行 `/opt/rollback.sh` 回滚到最近备份。

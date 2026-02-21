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

## 2. 安装业务套件

### 方法一：自动安装（推荐）

```bash
# 进入 proot 环境
proot-distro login debian

# 克隆仓库
git clone https://github.com/YOUR_USERNAME/termux-proot-services.git
cd termux-proot-services

# 运行安装脚本
chmod +x install.sh
./install.sh
```

### 方法二：手动安装

```bash
# 进入 proot
proot-distro login debian

# 安装依赖
apt update && apt upgrade -y
apt install -y wget curl unzip git nodejs pnpm sqlite3

# 安装 PM2
npm install -g pm2

# 下载服务
# 参考 install.sh 中的步骤手动执行
```

## 3. 配置服务

### ASF 配置

```bash
# 编辑主配置
nano /opt/ASF/config/ASF.json
```

修改以下内容：
```json
{
  "IPCPassword": "你的安全密码",
  "SteamOwnerID": 你的 SteamID64
}
```

添加 Steam 账号：
```bash
# 复制 bot 配置模板
cp /opt/ASF/config/Squad.json /opt/ASF/config/MyBot.json

# 编辑配置
nano /opt/ASF/config/MyBot.json
```

### MCSManager 配置

首次访问 Web 面板会引导你完成初始设置。

## 4. 启动服务

```bash
# 所有服务已通过 PM2 自动启动
pm2 list

# 查看日志
pm2 logs

# 重启服务
pm2 restart all
```

## 5. 访问服务

- **MCSManager**: http://localhost:23333
- **ASF IPC**: http://localhost:1242 (需要密码)

## 6. 配置开机自启

在 Termux 中创建启动脚本：

```bash
# 在 Termux (不是 proot) 中编辑
nano ~/.termux/boot-services.sh
```

添加内容：
```bash
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login debian -- sudo service ssh start
proot-distro login debian -- pm2 resurrect
```

## 7. VSCode Remote SSH 配置

1. 安装 VSCode Remote SSH 扩展
2. 添加 SSH 主机：`ssh root@localhost -p 2222`
3. 连接即可远程编辑 proot 内的文件

## 常见问题

### Q: 服务无法启动
A: 检查 PM2 日志 `pm2 logs`，确认端口未被占用

### Q: 网络无法访问
A: 确保 proot-distro 正确配置了网络绑定

### Q: 如何备份配置
A: 运行 `/opt/update-all.sh` 会自动备份所有配置

### Q: 更新失败怎么办
A: 运行 `/opt/rollback.sh` 回滚到之前的版本

## 8. 可选：部署 Aria2 + AriaNg + Caddy

```bash
# 在 Debian proot 中执行
/opt/deploy-aria2.sh
```

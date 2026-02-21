# 🚀 Termux proot 业务管理套件

> 在 Android Termux + proot-distro 环境下运行的轻量级业务管理方案

## 📦 包含服务

| 服务 | 说明 | 端口 |
|------|------|------|
| **ArchiSteamFarm** | Steam 自动挂卡 | IPC: 1242 |
| **MCSManager** | Minecraft 服务器管理面板 | Web: 23333 / 守护：24444 |
| **PM2** | 进程管理 & 自启 | - |

## 🎯 特性

- ✅ 专为 **Termux + proot-distro** 优化
- ✅ 支持 **VSCode Remote SSH** 远程开发
- ✅ 使用 **Gitee 镜像源** 加速下载
- ✅ 完整的配置备份 & 回滚机制
- ✅ 使用 **pnpm** 管理 Node.js 依赖
- ✅ 一键安装/更新/回滚

## 📋 系统要求

- Android 设备
- Termux (F-Droid 版本推荐)
- proot-distro 已安装
- Debian 11+ (proot 环境)

## 🚀 快速开始

### 1. 安装 Termux 和 proot-distro

```bash
# Termux 内安装 proot-distro
pkg update
pkg install proot-distro
proot-distro install debian
```

### 2. 启动 proot 并安装本套件

```bash
# 进入 proot 环境
proot-distro login debian

# 克隆本仓库
git clone https://github.com/YOUR_USERNAME/termux-proot-services.git
cd termux-proot-services

# 运行安装脚本
./install.sh
```

### 3. 访问服务

- **MCSManager Web**: http://localhost:23333
- **ASF IPC**: http://localhost:1242 (需要密码)

## 📁 目录结构

```
/opt/
├── ASF/                    # ArchiSteamFarm
│   ├── config/            # ASF 配置文件
│   └── ArchiSteamFarm     # 主程序
├── mcsmanager/            # MCSManager
│   ├── daemon/           # 守护进程
│   └── web/              # Web 面板
├── backups/              # 自动备份目录
├── update-all.sh         # 全量更新脚本
├── update-asf.sh         # ASF 更新脚本
├── update-mcs.sh         # MCSManager 更新脚本
└── rollback.sh           # 回滚脚本
```

## 🔧 常用命令

### PM2 管理

```bash
pm2 list              # 查看服务状态
pm2 logs              # 查看日志
pm2 restart all       # 重启所有服务
pm2 save --force      # 保存进程列表
pm2 monit             # 实时监控
```

### 更新服务

```bash
# 更新所有服务
/opt/update-all.sh

# 仅更新 ASF
/opt/update-asf.sh

# 仅更新 MCSManager
/opt/update-mcs.sh
```

### 回滚

```bash
# 回滚到上次备份
/opt/rollback.sh
```

## ⚙️ 配置说明

### ASF 配置

编辑 `/opt/ASF/config/ASF.json`:

```json
{
  "Headless": true,
  "IPCPassword": "你的密码",
  "SteamOwnerID": 你的 SteamID
}
```

编辑 bot 配置 `/opt/ASF/config/<bot 名>.json`:

```json
{
  "Enabled": true,
  "SteamLogin": "账号",
  "SteamPassword": "密码",
  "SteamSteamGuard": "2FA 代码 (可选)"
}
```

### MCSManager 配置

- **Web 面板**: `/opt/mcsmanager/web/data/SystemConfig/config.json`
- **守护进程**: `/opt/mcsmanager/daemon/data/Config/global.json`

## 🔒 安全建议

1. 修改默认密码
2. 仅在信任的网络环境使用
3. 定期备份配置
4. 不要以 root 运行（proot 内风险可控）

## 📝 备份策略

每次更新前自动备份到 `/opt/backups/日期_时间/`

备份内容包括:
- ASF 配置文件
- MCSManager 所有配置
- 实例配置

## 🐛 故障排除

### 服务无法启动

```bash
# 查看 PM2 日志
pm2 logs

# 重启服务
pm2 restart <服务名>
```

### 配置丢失

```bash
# 从备份恢复
/opt/rollback.sh
```

### 网络问题

确保 proot 启动时正确配置了网络绑定。

## 📄 License

MIT License

## 🙏 致谢

- [ArchiSteamFarm](https://github.com/JustArchiNET/ArchiSteamFarm)
- [MCSManager](https://github.com/MCSManager/MCSManager)
- [proot-distro](https://github.com/termux/proot-distro)
- [PM2](https://github.com/Unitech/pm2)

## 📱 相关资源

- [Termux 官网](https://termux.dev/)
- [proot-distro 文档](https://github.com/termux/proot-distro)
- [VSCode Remote SSH](https://code.visualstudio.com/docs/remote/ssh)

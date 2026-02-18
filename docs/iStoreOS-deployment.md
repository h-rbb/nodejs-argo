# iStoreOS 部署指南 (iStoreOS Deployment Guide)

## 系统要求 (System Requirements)

### 硬件配置
- 路由器型号：亚瑟AX1800Pro或其他支持的型号
- 内存：建议1GB或以上
- 存储：至少100MB可用空间

### 软件环境
- 系统：iStoreOS R24.05.19 或更高版本
- Node.js：14.0 或更高版本
- Firewall4：最新版本

## 安装步骤 (Installation Steps)

### 1. 准备iStoreOS环境

首先确保您的路由器已经刷入iStoreOS系统，并且网络连接正常。

```bash
# 通过SSH连接到路由器
ssh root@192.168.1.1
```

### 2. 安装Node.js环境

iStoreOS基于OpenWRT，需要先安装Node.js：

```bash
# 更新软件包列表
opkg update

# 安装Node.js
opkg install node node-npm

# 验证安装
node --version
npm --version
```

### 3. 安装nodejs-argo

```bash
# 全局安装nodejs-argo
npm install -g nodejs-argo

# 或者克隆仓库手动安装
cd /opt
git clone https://github.com/h-rbb/nodejs-argo.git
cd nodejs-argo
npm install
```

### 4. 配置环境变量

创建配置文件 `/etc/nodejs-argo.env`:

```bash
# 创建环境变量配置
cat > /etc/nodejs-argo.env << 'EOF'
# 基础配置
PORT=3000
ARGO_PORT=8001
UUID=your-uuid-here

# Argo隧道配置（可选）
ARGO_DOMAIN=
ARGO_AUTH=

# 哪吒探针配置（可选）
NEZHA_SERVER=
NEZHA_PORT=
NEZHA_KEY=

# 节点配置
CFIP=cdns.doon.eu.org
CFPORT=443
NAME=AX1800Pro

# 订阅配置（可选）
UPLOAD_URL=
PROJECT_URL=
AUTO_ACCESS=false

# 文件路径
FILE_PATH=/opt/nodejs-argo/tmp
SUB_PATH=sub
EOF
```

### 5. 配置Firewall4

确保Firewall4允许nodejs-argo所需的端口：

```bash
# 编辑防火墙规则
vi /etc/config/firewall
```

添加以下规则：

```
# nodejs-argo端口转发
config rule
    option name 'Allow-nodejs-argo-HTTP'
    option src 'wan'
    option dest_port '3000'
    option target 'ACCEPT'
    option proto 'tcp'

config rule
    option name 'Allow-nodejs-argo-Argo'
    option src 'wan'
    option dest_port '8001'
    option target 'ACCEPT'
    option proto 'tcp'
```

重启防火墙：

```bash
/etc/init.d/firewall restart
```

## 与luci-app-homeproxy集成 (Integration with luci-app-homeproxy)

### 兼容性说明

nodejs-argo生成的节点可以与luci-app-homeproxy配合使用：

1. nodejs-argo作为节点生成器，创建VLESS/VMess/Trojan节点
2. luci-app-homeproxy作为代理客户端，使用这些节点

### 配置步骤

1. 启动nodejs-argo服务获取订阅地址：
   ```
   http://路由器IP:3000/sub
   ```

2. 在luci-app-homeproxy中添加订阅：
   - 登录路由器管理界面
   - 进入 Services → HomeProxy
   - 添加订阅地址：`http://127.0.0.1:3000/sub`
   - 更新订阅并选择节点

### 注意事项

- nodejs-argo和luci-app-homeproxy可以在同一台路由器上运行
- 确保端口不冲突（nodejs-argo默认3000，homeproxy通常使用其他端口）
- nodejs-argo生成的节点通过Argo隧道连接，无需在路由器上开放额外端口

## 自动启动配置 (Auto-start Configuration)

### 创建init.d服务脚本

```bash
cat > /etc/init.d/nodejs-argo << 'EOF'
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1
PROG=/usr/bin/node
ARGS="/usr/lib/node_modules/nodejs-argo/index.js"

start_service() {
    procd_open_instance
    procd_set_param command $PROG $ARGS
    procd_set_param env PORT=3000 ARGO_PORT=8001
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    # procd will handle stopping the service automatically
    echo "Stopping nodejs-argo..."
}
EOF

# 添加执行权限
chmod +x /etc/init.d/nodejs-argo

# 设置开机自启
/etc/init.d/nodejs-argo enable

# 启动服务
/etc/init.d/nodejs-argo start
```

### 使用systemd（如果系统支持）

```bash
cat > /etc/systemd/system/nodejs-argo.service << 'EOF'
[Unit]
Description=Node.js Argo Tunnel Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/nodejs-argo
EnvironmentFile=/etc/nodejs-argo.env
ExecStart=/usr/bin/node /opt/nodejs-argo/index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 重载systemd
systemctl daemon-reload

# 启动并启用服务
systemctl start nodejs-argo
systemctl enable nodejs-argo
```

## 双频合一配置 (Dual-band WiFi Configuration)

虽然nodejs-argo本身不处理WiFi配置，但您可以在iStoreOS中配置双频合一：

```bash
# 编辑无线配置
vi /etc/config/wireless
```

配置示例：

```
config wifi-iface 'default_radio0'
    option device 'radio0'
    option network 'lan'
    option mode 'ap'
    option ssid 'YourSSID'
    option encryption 'psk2'
    option key 'YourPassword'

config wifi-iface 'default_radio1'
    option device 'radio1'
    option network 'lan'
    option mode 'ap'
    option ssid 'YourSSID'  # 使用相同的SSID实现双频合一
    option encryption 'psk2'
    option key 'YourPassword'
```

重启无线服务：

```bash
wifi reload
```

## 自动拨号上网配置 (Auto PPPoE Dial-up)

配置自动拨号（如果您使用PPPoE）：

```bash
# 编辑网络配置
vi /etc/config/network
```

配置WAN接口：

```
config interface 'wan'
    option ifname 'eth1'
    option proto 'pppoe'
    option username 'your-isp-username'
    option password 'your-isp-password'
    option peerdns '1'
    option auto '1'
```

重启网络服务：

```bash
/etc/init.d/network restart
```

## 常见问题 (Troubleshooting)

### 1. 服务无法启动

检查日志：
```bash
logread | grep nodejs-argo
```

检查进程：
```bash
ps | grep node
```

### 2. 内存不足

如果路由器内存较小，可以：
- 减少其他服务
- 使用swap分区
- 调整nodejs-argo配置减少资源占用

### 3. 端口冲突

检查端口占用：
```bash
netstat -tulpn | grep -E '(3000|8001)'
```

修改端口：
```bash
export PORT=3001
export ARGO_PORT=8002
```

### 4. Argo隧道连接失败

- 检查网络连接
- 确认防火墙规则正确
- 查看cloudflared日志：`/opt/nodejs-argo/tmp/boot.log`

## 性能优化建议 (Performance Optimization)

1. **内存优化**：
   ```bash
   # 设置Node.js内存限制
   export NODE_OPTIONS="--max-old-space-size=256"
   ```

2. **定期清理**：
   ```bash
   # 添加定时任务清理临时文件
   echo "0 3 * * * rm -rf /opt/nodejs-argo/tmp/*" >> /etc/crontabs/root
   ```

3. **监控资源**：
   ```bash
   # 查看内存使用
   free -m
   
   # 查看CPU使用
   top
   ```

## 第三方插件支持 (Third-party Plugin Support)

iStoreOS支持多种第三方插件，以下插件可与nodejs-argo配合使用：

- **luci-app-homeproxy**: 代理客户端
- **luci-app-openclash**: 另一个代理选择
- **luci-app-ddns**: 动态域名解析
- **luci-app-upnp**: 端口转发
- **luci-app-ttyd**: Web终端
- **luci-app-statistics**: 系统监控

### 安装第三方插件

```bash
# 更新软件包列表
opkg update

# 搜索可用插件
opkg list | grep luci-app

# 安装插件示例
opkg install luci-app-homeproxy
```

## 更新和维护 (Updates and Maintenance)

### 更新nodejs-argo

```bash
# 如果是npm全局安装
npm update -g nodejs-argo

# 如果是git克隆安装
cd /opt/nodejs-argo
git pull
npm install
/etc/init.d/nodejs-argo restart
```

### 备份配置

```bash
# 备份环境变量配置
cp /etc/nodejs-argo.env /etc/nodejs-argo.env.backup

# 备份防火墙规则
cp /etc/config/firewall /etc/config/firewall.backup
```

## 安全建议 (Security Recommendations)

1. **修改默认UUID**：使用自己的UUID替换默认值
2. **使用固定隧道**：配置ARGO_DOMAIN和ARGO_AUTH提高稳定性
3. **限制访问**：在防火墙中限制管理端口的访问来源
4. **定期更新**：保持系统和应用程序更新
5. **备份配置**：定期备份重要配置文件

## 技术支持 (Technical Support)

- GitHub Issues: https://github.com/h-rbb/nodejs-argo/issues
- Telegram群组: https://t.me/eooceu

## 许可证 (License)

本项目遵循GPL 3.0许可证，仅限个人使用，禁止商业用途。

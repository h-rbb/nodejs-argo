# OpenWrt/iStoreOS 部署指南

本指南说明如何在 OpenWrt/iStoreOS 路由器系统上部署 nodejs-argo 并配置与 luci-app-homeproxy 的兼容性。

## 系统要求

- **路由器型号**: 亚瑟AX1800Pro (1GB内存)
- **系统**: iStoreOS R24.05.19 或更高版本
- **固件**: firewall4 支持
- **必需软件包**:
  - node.js (v14+)
  - luci-app-homeproxy
  - firewall4

## 安装步骤

### 1. 准备系统

```bash
# 更新软件包列表
opkg update

# 安装 Node.js 和 npm
opkg install node node-npm

# 安装 homeproxy 相关包
opkg install luci-app-homeproxy

# 确保 firewall4 已安装
opkg install firewall4
```

### 2. 安装 nodejs-argo

```bash
# 全局安装
npm install -g nodejs-argo

# 或者使用 npx
npx nodejs-argo
```

### 3. 配置环境变量

在 `/etc/config/` 目录下创建配置文件，或使用环境变量：

```bash
# 创建环境变量文件
cat > /etc/nodejs-argo.env << 'EOF'
# 基础配置
PORT=3000
ARGO_PORT=8001
UUID=89c13786-25aa-4520-b2e7-12cd60fb5202

# Argo 隧道配置（可选，留空使用临时隧道）
ARGO_DOMAIN=
ARGO_AUTH=

# 优选 IP/域名
CFIP=cdns.doon.eu.org
CFPORT=443

# 节点名称
NAME=iStoreOS-AX1800Pro

# 哪吒探针（可选）
NEZHA_SERVER=
NEZHA_PORT=
NEZHA_KEY=

# 订阅路径
SUB_PATH=sub
FILE_PATH=/tmp/nodejs-argo

# 自动保活（可选）
AUTO_ACCESS=false
PROJECT_URL=
UPLOAD_URL=
EOF

# 加载环境变量
export $(cat /etc/nodejs-argo.env | xargs)
```

### 4. 创建系统服务

创建 `/etc/init.d/nodejs-argo` 服务脚本：

```bash
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1
PROG=/usr/bin/node
ARGS="/usr/lib/node_modules/nodejs-argo/index.js"

start_service() {
    procd_open_instance
    procd_set_param command $PROG $ARGS
    
    # 加载环境变量
    [ -f /etc/nodejs-argo.env ] && {
        . /etc/nodejs-argo.env
        procd_set_param env PORT="$PORT"
        procd_set_param env ARGO_PORT="$ARGO_PORT"
        procd_set_param env UUID="$UUID"
        procd_set_param env CFIP="$CFIP"
        procd_set_param env CFPORT="$CFPORT"
        procd_set_param env NAME="$NAME"
        procd_set_param env SUB_PATH="$SUB_PATH"
        procd_set_param env FILE_PATH="$FILE_PATH"
        procd_set_param env ARGO_DOMAIN="$ARGO_DOMAIN"
        procd_set_param env ARGO_AUTH="$ARGO_AUTH"
    }
    
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    killall node 2>/dev/null
}

restart() {
    stop
    sleep 2
    start
}
```

启用服务：

```bash
# 设置执行权限
chmod +x /etc/init.d/nodejs-argo

# 启用开机自启
/etc/init.d/nodejs-argo enable

# 启动服务
/etc/init.d/nodejs-argo start
```

## luci-app-homeproxy 集成

### 1. 获取节点信息

启动 nodejs-argo 后，通过以下方式获取节点信息：

```bash
# 访问订阅地址
curl http://192.168.1.1:3000/sub

# 或查看日志获取临时隧道域名
logread | grep "ArgoDomain"
```

### 2. 配置 homeproxy

1. 登录 LuCI 管理界面：`http://192.168.1.1`
2. 进入 **服务 → HomeProxy**
3. 点击 **节点管理 → 添加节点**

#### VLESS 节点配置

- **节点名称**: `iStoreOS-VLESS`
- **协议**: `VLESS`
- **地址**: 使用 `CFIP` 值（如 `cdns.doon.eu.org`）
- **端口**: `443`
- **UUID**: 你的 UUID
- **传输协议**: `WebSocket`
- **路径**: `/vless-argo?ed=2560`
- **TLS**: 启用
- **SNI**: Argo 域名
- **指纹**: `firefox`

#### VMess 节点配置

- **节点名称**: `iStoreOS-VMess`
- **协议**: `VMess`
- **地址**: 使用 `CFIP` 值
- **端口**: `443`
- **UUID**: 你的 UUID
- **额外ID**: `0`
- **传输协议**: `WebSocket`
- **路径**: `/vmess-argo?ed=2560`
- **TLS**: 启用
- **SNI**: Argo 域名

#### Trojan 节点配置

- **节点名称**: `iStoreOS-Trojan`
- **协议**: `Trojan`
- **地址**: 使用 `CFIP` 值
- **端口**: `443`
- **密码**: 你的 UUID
- **传输协议**: `WebSocket`
- **路径**: `/trojan-argo?ed=2560`
- **TLS**: 启用
- **SNI**: Argo 域名

### 3. 使用配置模板

你也可以使用提供的 `homeproxy-config.json` 模板：

```bash
# 复制模板到 homeproxy 配置目录
cp homeproxy-config.json /etc/homeproxy/

# 修改占位符
sed -i "s/REPLACE_WITH_CFIP/$CFIP/g" /etc/homeproxy/homeproxy-config.json
sed -i "s/REPLACE_WITH_UUID/$UUID/g" /etc/homeproxy/homeproxy-config.json
sed -i "s/REPLACE_WITH_ARGO_DOMAIN/你的Argo域名/g" /etc/homeproxy/homeproxy-config.json
```

## Firewall4 配置

### 1. 升级 Firewall4

```bash
# 如果系统使用 firewall3，升级到 firewall4
opkg remove firewall3
opkg install firewall4

# 重启防火墙服务
/etc/init.d/firewall restart
```

### 2. 配置防火墙规则

编辑 `/etc/config/firewall`，添加以下规则：

```
# 允许 nodejs-argo HTTP 服务
config rule
    option name 'Allow-NodeJS-Argo-HTTP'
    option src 'lan'
    option dest_port '3000'
    option proto 'tcp'
    option target 'ACCEPT'

# 允许 Argo 隧道端口
config rule
    option name 'Allow-Argo-Tunnel'
    option src 'wan'
    option dest_port '8001'
    option proto 'tcp'
    option target 'ACCEPT'

# HomeProxy 透明代理规则
config redirect
    option name 'HomeProxy-Redirect'
    option src 'lan'
    option proto 'tcp udp'
    option dest 'wan'
    option target 'DNAT'
    option dest_ip '127.0.0.1'
    option dest_port '1088'
```

重新加载防火墙：

```bash
/etc/init.d/firewall reload
```

## 双频合一配置

### 配置无线网络

编辑 `/etc/config/wireless`:

```
config wifi-device 'radio0'
    option type 'mac80211'
    option hwmode '11a'
    option channel 'auto'
    option htmode 'HE80'
    option country 'CN'

config wifi-iface 'default_radio0'
    option device 'radio0'
    option network 'lan'
    option mode 'ap'
    option ssid 'AX1800Pro'  # 统一SSID
    option encryption 'psk2+ccmp'
    option key 'your-password'
    option ieee80211r '1'
    option ft_over_ds '0'
    option ft_psk_generate_local '1'

config wifi-device 'radio1'
    option type 'mac80211'
    option hwmode '11g'
    option channel 'auto'
    option htmode 'HE40'
    option country 'CN'

config wifi-iface 'default_radio1'
    option device 'radio1'
    option network 'lan'
    option mode 'ap'
    option ssid 'AX1800Pro'  # 相同SSID实现双频合一
    option encryption 'psk2+ccmp'
    option key 'your-password'
    option ieee80211r '1'
    option ft_over_ds '0'
    option ft_psk_generate_local '1'
```

重启无线服务：

```bash
wifi reload
```

## 自动拨号配置

### PPPoE 自动拨号

编辑 `/etc/config/network`:

```
config interface 'wan'
    option device 'eth1'
    option proto 'pppoe'
    option username '你的宽带账号'
    option password '你的宽带密码'
    option ipv6 'auto'
    option peerdns '0'
    option dns '223.5.5.5 119.29.29.29'
```

重启网络服务：

```bash
/etc/init.d/network restart
```

## 验证部署

### 1. 检查服务状态

```bash
# 检查 nodejs-argo 服务
/etc/init.d/nodejs-argo status

# 查看日志
logread | grep nodejs-argo

# 检查端口监听
netstat -tlnp | grep -E "3000|8001"
```

### 2. 测试订阅

```bash
# 获取订阅内容
curl http://localhost:3000/sub | base64 -d

# 测试 Argo 隧道
curl -I http://localhost:8001
```

### 3. 检查 homeproxy 状态

```bash
# 查看 homeproxy 运行状态
/etc/init.d/homeproxy status

# 测试代理连接
curl --proxy socks5://127.0.0.1:1080 https://www.google.com
```

## 常见问题

### 1. 内存不足

如果遇到内存不足，可以：
- 减少运行的服务数量
- 禁用不必要的软件包
- 使用 swap 分区

```bash
# 创建 swap
dd if=/dev/zero of=/tmp/swap bs=1M count=256
mkswap /tmp/swap
swapon /tmp/swap
```

### 2. Argo 隧道连接失败

- 检查网络连接
- 验证 ARGO_AUTH 和 ARGO_DOMAIN 配置
- 查看 cloudflared 日志

### 3. HomeProxy 无法连接

- 确保 nodejs-argo 服务正在运行
- 检查 UUID 配置是否一致
- 验证 Argo 域名是否正确
- 检查防火墙规则

## 性能优化

### 1. 调整 Node.js 内存限制

```bash
# 在服务脚本中添加
NODE_OPTIONS="--max-old-space-size=128"
```

### 2. 启用 BBR 拥塞控制

```bash
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
```

### 3. 优化 DNS 解析

在 `/etc/config/dhcp` 中配置 DNS 缓存：

```
config dnsmasq
    option cachesize '1500'
    option noresolv '1'
    list server '223.5.5.5'
    list server '119.29.29.29'
```

## 安全建议

1. **修改默认 UUID**: 不要使用默认的 UUID
2. **使用固定隧道**: 配置 ARGO_DOMAIN 和 ARGO_AUTH
3. **限制访问**: 配置防火墙规则限制 WAN 侧访问
4. **定期更新**: 保持系统和软件包更新

```bash
# 定期更新
opkg update
opkg upgrade nodejs-argo
npm update -g nodejs-argo
```

## 第三方插件推荐

在 iStoreOS 上可以安装的推荐插件：

1. **luci-app-adguardhome** - 广告过滤
2. **luci-app-ddns-go** - 动态 DNS
3. **luci-app-openclash** - 代理工具（与 homeproxy 二选一）
4. **luci-app-smartdns** - 智能 DNS
5. **luci-app-unblockneteasemusic** - 音乐解锁
6. **luci-app-passwall** - 代理工具（与 homeproxy 二选一）

安装方式：

```bash
# 在 iStoreOS 中
opkg update
opkg install <插件名>
```

## 备份与恢复

### 备份配置

```bash
# 备份配置文件
tar -czf /tmp/nodejs-argo-backup.tar.gz \
    /etc/nodejs-argo.env \
    /etc/init.d/nodejs-argo \
    /etc/config/wireless \
    /etc/config/network \
    /etc/config/firewall
```

### 恢复配置

```bash
# 恢复配置文件
tar -xzf /tmp/nodejs-argo-backup.tar.gz -C /
/etc/init.d/nodejs-argo restart
/etc/init.d/network restart
/etc/init.d/firewall restart
wifi reload
```

## 更多资源

- [OpenWrt 官方文档](https://openwrt.org/docs)
- [iStoreOS 文档](https://doc.istoreos.com/)
- [luci-app-homeproxy GitHub](https://github.com/immortalwrt/homeproxy)
- [Argo Tunnel 文档](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

## 技术支持

- Telegram 交流群: https://t.me/eooceu
- GitHub Issues: https://github.com/eooce/nodejs-argo/issues

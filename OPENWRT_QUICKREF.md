# OpenWrt/iStoreOS 快速参考

## 一键部署

```bash
# 下载部署脚本
wget -O /tmp/install.sh https://raw.githubusercontent.com/eooce/nodejs-argo/main/install-openwrt.sh
chmod +x /tmp/install.sh

# 运行部署
sh /tmp/install.sh

# 生成 HomeProxy 配置
sh generate-homeproxy-config.sh
```

## 服务管理

```bash
# 启动服务
/etc/init.d/nodejs-argo start

# 停止服务
/etc/init.d/nodejs-argo stop

# 重启服务
/etc/init.d/nodejs-argo restart

# 查看状态
/etc/init.d/nodejs-argo status

# 启用开机自启
/etc/init.d/nodejs-argo enable

# 禁用开机自启
/etc/init.d/nodejs-argo disable
```

## 配置文件

| 文件 | 说明 |
|------|------|
| `/etc/nodejs-argo.env` | 环境变量配置 |
| `/etc/init.d/nodejs-argo` | 系统服务脚本 |
| `/tmp/nodejs-argo/` | 运行时临时文件 |
| `/etc/homeproxy/nodejs-argo-nodes.json` | HomeProxy 节点配置 |

## 常用命令

### 查看日志
```bash
# 查看系统日志
logread | grep nodejs

# 查看实时日志
logread -f | grep nodejs

# 查看 boot.log (Argo 隧道日志)
cat /tmp/nodejs-argo/boot.log
```

### 查看订阅
```bash
# 获取订阅地址
LAN_IP=$(uci get network.lan.ipaddr)
echo "http://${LAN_IP}:3000/sub"

# 查看订阅内容
curl http://localhost:3000/sub | base64 -d
```

### 查看 Argo 域名
```bash
# 从日志提取
logread | grep "ArgoDomain"

# 或从 boot.log 提取
grep -oP 'https://\K[^/]*trycloudflare\.com' /tmp/nodejs-argo/boot.log
```

### 检查端口
```bash
# 查看监听端口
netstat -tlnp | grep -E "3000|8001"

# 或使用 ss 命令
ss -tlnp | grep -E "3000|8001"
```

## 环境变量

编辑 `/etc/nodejs-argo.env`:

```bash
# 基础配置
PORT=3000                    # HTTP 订阅服务端口
ARGO_PORT=8001              # Argo 隧道端口
UUID=<生成的UUID>           # 节点 UUID

# Argo 隧道 (可选)
ARGO_DOMAIN=                # 固定隧道域名
ARGO_AUTH=                  # 固定隧道密钥

# 优选配置
CFIP=cdns.doon.eu.org      # 优选域名/IP
CFPORT=443                  # 优选端口

# 节点名称
NAME=iStoreOS-AX1800Pro     # 节点名称前缀

# 哪吒探针 (可选)
NEZHA_SERVER=               # 哪吒服务器地址
NEZHA_PORT=                 # 哪吒端口
NEZHA_KEY=                  # 哪吒密钥

# 其他配置
SUB_PATH=sub                # 订阅路径
FILE_PATH=/tmp/nodejs-argo  # 运行目录
AUTO_ACCESS=false           # 自动保活
```

修改后重启服务:
```bash
/etc/init.d/nodejs-argo restart
```

## HomeProxy 配置

### 方式1: 使用订阅 (推荐)

1. 登录 LuCI: `http://192.168.1.1`
2. 进入: **服务 → HomeProxy → 订阅管理**
3. 添加订阅: `http://192.168.1.1:3000/sub`
4. 更新订阅并启用节点

### 方式2: 手动添加节点

获取配置信息:
```bash
sh generate-homeproxy-config.sh
```

在 HomeProxy 中手动填写显示的节点信息。

### 方式3: UCI 命令

```bash
# 使用 generate-homeproxy-config.sh 输出的 UCI 命令
# 复制并执行命令即可
```

## 防火墙规则

查看规则:
```bash
uci show firewall | grep nodejs
```

手动添加规则:
```bash
# HTTP 服务
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-NodeJS-Argo-HTTP'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest_port='3000'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'

# Argo 隧道
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-Argo-Tunnel'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='8001'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'

# 提交并重载
uci commit firewall
/etc/init.d/firewall reload
```

## 网络配置

### PPPoE 拨号

编辑 `/etc/config/network`:
```bash
config interface 'wan'
    option device 'eth1'
    option proto 'pppoe'
    option username '宽带账号'
    option password '宽带密码'
    option ipv6 'auto'
```

重启网络:
```bash
/etc/init.d/network restart
```

### 双频合一 WiFi

编辑 `/etc/config/wireless`:
```bash
# 5GHz
config wifi-iface 'default_radio0'
    option device 'radio0'
    option network 'lan'
    option mode 'ap'
    option ssid 'YourWiFiName'    # 相同 SSID
    option encryption 'psk2+ccmp'
    option key 'YourPassword'
    option ieee80211r '1'          # 启用快速漫游

# 2.4GHz
config wifi-iface 'default_radio1'
    option device 'radio1'
    option network 'lan'
    option mode 'ap'
    option ssid 'YourWiFiName'    # 相同 SSID
    option encryption 'psk2+ccmp'
    option key 'YourPassword'
    option ieee80211r '1'          # 启用快速漫游
```

重启 WiFi:
```bash
wifi reload
```

## 故障排除

### 服务无法启动
```bash
# 检查 Node.js 是否安装
node --version
npm --version

# 检查配置文件
cat /etc/nodejs-argo.env

# 查看错误日志
logread | tail -50
```

### 无法获取订阅
```bash
# 检查服务状态
/etc/init.d/nodejs-argo status

# 检查端口
netstat -tlnp | grep 3000

# 测试连接
curl http://localhost:3000/sub
```

### Argo 隧道连接失败
```bash
# 查看 cloudflared 日志
cat /tmp/nodejs-argo/boot.log

# 检查网络连接
ping 1.1.1.1

# 重启服务
/etc/init.d/nodejs-argo restart
```

### HomeProxy 无法连接
```bash
# 检查节点配置
cat /etc/homeproxy/nodejs-argo-nodes.json

# 查看 HomeProxy 日志
logread | grep homeproxy

# 测试代理
curl --proxy socks5://127.0.0.1:1080 https://www.google.com
```

### 内存不足
```bash
# 查看内存使用
free -m

# 创建 swap
dd if=/dev/zero of=/tmp/swap bs=1M count=256
mkswap /tmp/swap
swapon /tmp/swap

# 开机自动挂载 (添加到 /etc/rc.local)
echo "swapon /tmp/swap" >> /etc/rc.local
```

## 性能优化

### 启用 BBR
```bash
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
```

### DNS 优化
```bash
# 编辑 /etc/config/dhcp
uci set dhcp.@dnsmasq[0].cachesize='1500'
uci set dhcp.@dnsmasq[0].noresolv='1'
uci add_list dhcp.@dnsmasq[0].server='223.5.5.5'
uci add_list dhcp.@dnsmasq[0].server='119.29.29.29'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

## 备份与恢复

### 备份
```bash
tar -czf /tmp/nodejs-argo-backup.tar.gz \
    /etc/nodejs-argo.env \
    /etc/init.d/nodejs-argo \
    /etc/config/wireless \
    /etc/config/network \
    /etc/config/firewall

# 下载备份
# 在浏览器中访问: http://192.168.1.1/cgi-bin/luci/admin/system/backup
```

### 恢复
```bash
# 上传备份文件后
tar -xzf /tmp/nodejs-argo-backup.tar.gz -C /
/etc/init.d/nodejs-argo restart
/etc/init.d/network restart
/etc/init.d/firewall restart
wifi reload
```

## 更新

### 更新 nodejs-argo
```bash
npm update -g nodejs-argo
/etc/init.d/nodejs-argo restart
```

### 更新系统
```bash
opkg update
opkg list-upgradable
opkg upgrade <package-name>
```

## 卸载

```bash
# 停止并禁用服务
/etc/init.d/nodejs-argo stop
/etc/init.d/nodejs-argo disable

# 删除服务文件
rm /etc/init.d/nodejs-argo

# 删除配置文件
rm /etc/nodejs-argo.env

# 卸载 nodejs-argo
npm uninstall -g nodejs-argo

# 清理临时文件
rm -rf /tmp/nodejs-argo
```

## 相关链接

- [完整部署指南](OPENWRT_GUIDE.md)
- [项目主页](README.md)
- [GitHub 仓库](https://github.com/eooce/nodejs-argo)
- [问题反馈](https://github.com/eooce/nodejs-argo/issues)
- [Telegram 群组](https://t.me/eooceu)

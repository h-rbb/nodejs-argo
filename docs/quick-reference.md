# iStoreOS/OpenWRT 快速参考 (Quick Reference)

## 一键安装 (One-line Installation)

```bash
wget -O - https://raw.githubusercontent.com/h-rbb/nodejs-argo/main/scripts/install-istoreos.sh | sh
```

或者使用curl:

```bash
curl -fsSL https://raw.githubusercontent.com/h-rbb/nodejs-argo/main/scripts/install-istoreos.sh | sh
```

## 常用命令 (Common Commands)

### 服务管理

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

### 配置管理

```bash
# 编辑配置文件
vi /etc/nodejs-argo.env

# 查看配置
cat /etc/nodejs-argo.env

# 备份配置
cp /etc/nodejs-argo.env /etc/nodejs-argo.env.backup

# 恢复配置
cp /etc/nodejs-argo.env.backup /etc/nodejs-argo.env
```

### 日志查看

```bash
# 查看系统日志
logread | grep nodejs-argo

# 实时查看日志
logread -f | grep nodejs-argo

# 查看Node进程
ps | grep node

# 查看端口占用
netstat -tulpn | grep -E '(3000|8001)'
```

### 防火墙配置

```bash
# 查看防火墙规则
uci show firewall | grep nodejs-argo

# 重启防火墙
/etc/init.d/firewall restart

# 查看开放端口
iptables -L -n | grep -E '(3000|8001)'
```

## 订阅地址 (Subscription URL)

### 局域网访问

```
http://192.168.1.1:3000/sub
```

### 公网访问（需要配置端口转发）

```
http://你的公网IP:3000/sub
```

### 配合luci-app-homeproxy使用

1. 打开路由器管理页面
2. 进入 Services → HomeProxy
3. 添加订阅地址: `http://127.0.0.1:3000/sub`
4. 更新订阅并选择节点

## 配置示例 (Configuration Examples)

### 最小配置

```bash
# /etc/nodejs-argo.env
PORT=3000
ARGO_PORT=8001
UUID=your-unique-uuid-here
```

### 完整配置（含哪吒监控）

```bash
PORT=3000
ARGO_PORT=8001
UUID=your-unique-uuid-here

# 哪吒探针
NEZHA_SERVER=nz.example.com:8008
NEZHA_KEY=your-nezha-key

# 节点名称
NAME=AX1800Pro

# 优选IP
CFIP=cdns.doon.eu.org
CFPORT=443
```

### 固定隧道配置

```bash
PORT=3000
ARGO_PORT=8001
UUID=your-unique-uuid-here

# 固定隧道
ARGO_DOMAIN=tunnel.example.com
ARGO_AUTH=your-cloudflare-token-or-json
```

## 故障排除 (Troubleshooting)

### 服务无法启动

```bash
# 检查Node.js是否安装
node --version
npm --version

# 检查nodejs-argo是否安装
which node
ls -la /usr/lib/node_modules/nodejs-argo/
ls -la /opt/nodejs-argo/

# 检查配置文件
cat /etc/nodejs-argo.env

# 手动运行查看错误
cd /opt/nodejs-argo  # 或 cd /usr/lib/node_modules/nodejs-argo
node index.js
```

### 端口被占用

```bash
# 查看3000端口占用
netstat -tulpn | grep 3000

# 查看8001端口占用
netstat -tulpn | grep 8001

# 修改端口
vi /etc/nodejs-argo.env
# 修改 PORT 和 ARGO_PORT 的值
```

### 内存不足

```bash
# 查看内存使用
free -m

# 查看进程内存
top -b -n 1 | head -20

# 清理内存缓存
sync && echo 3 > /proc/sys/vm/drop_caches

# 调整Node.js内存限制
# 编辑 /etc/nodejs-argo.env
NODE_OPTIONS="--max-old-space-size=128"  # 减小内存限制
```

### 无法访问订阅

```bash
# 测试本地访问
wget -O- http://127.0.0.1:3000/sub

# 测试局域网访问
wget -O- http://192.168.1.1:3000/sub

# 检查防火墙
iptables -L -n | grep 3000

# 添加防火墙规则
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-nodejs-argo'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='3000'
uci set firewall.@rule[-1].target='ACCEPT'
uci set firewall.@rule[-1].proto='tcp'
uci commit firewall
/etc/init.d/firewall restart
```

## 性能优化 (Performance Optimization)

### 针对1GB RAM设备

```bash
# 设置较小的内存限制
NODE_OPTIONS="--max-old-space-size=256"

# 使用固定隧道减少资源消耗
ARGO_DOMAIN=your-domain.com
ARGO_AUTH=your-token

# 定时清理临时文件
echo "0 3 * * * rm -rf /opt/nodejs-argo/tmp/*" >> /etc/crontabs/root
/etc/init.d/cron restart
```

### 减少日志输出

修改 `/etc/init.d/nodejs-argo`，将以下行：

```bash
procd_set_param stdout 1
procd_set_param stderr 1
```

改为：

```bash
procd_set_param stdout 0
procd_set_param stderr 0
```

## 更新nodejs-argo (Update)

### npm全局安装方式

```bash
npm update -g nodejs-argo
/etc/init.d/nodejs-argo restart
```

### Git克隆安装方式

```bash
cd /opt/nodejs-argo
git pull
npm install
/etc/init.d/nodejs-argo restart
```

## 卸载 (Uninstallation)

```bash
# 停止并禁用服务
/etc/init.d/nodejs-argo stop
/etc/init.d/nodejs-argo disable

# 删除服务脚本
rm -f /etc/init.d/nodejs-argo

# 删除配置文件
rm -f /etc/nodejs-argo.env

# 删除防火墙规则
uci delete firewall.@rule[$(uci show firewall | grep "nodejs-argo" | cut -d'[' -f2 | cut -d']' -f1)]
uci commit firewall
/etc/init.d/firewall restart

# 卸载nodejs-argo (npm方式)
npm uninstall -g nodejs-argo

# 或删除手动安装的文件 (git方式)
rm -rf /opt/nodejs-argo
```

## 获取帮助 (Get Help)

- 📖 完整文档: [iStoreOS部署指南](iStoreOS-deployment.md)
- 🐛 GitHub Issues: https://github.com/h-rbb/nodejs-argo/issues
- 💬 Telegram群组: https://t.me/eooceu

## 安全提醒 (Security Reminder)

1. 修改默认UUID
2. 不要在公共场合分享您的配置文件
3. 定期更新系统和应用
4. 使用强密码保护路由器管理界面
5. 仅供个人使用，禁止商业用途

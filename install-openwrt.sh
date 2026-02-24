#!/bin/sh
# OpenWrt/iStoreOS 快速部署脚本
# 用于在路由器上快速部署 nodejs-argo 和 luci-app-homeproxy

set -e

echo "=========================================="
echo "nodejs-argo OpenWrt/iStoreOS 部署脚本"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为 root 用户
if [ "$(id -u)" != "0" ]; then
   echo "${RED}错误: 此脚本需要 root 权限运行${NC}"
   exit 1
fi

# 检测系统
if [ ! -f "/etc/openwrt_release" ]; then
    echo "${RED}错误: 未检测到 OpenWrt 系统${NC}"
    exit 1
fi

echo "${GREEN}✓ 检测到 OpenWrt 系统${NC}"

# 检查网络连接
echo "检查网络连接..."
if ! ping -c 1 223.5.5.5 > /dev/null 2>&1; then
    echo "${RED}错误: 无法连接到互联网，请检查网络配置${NC}"
    exit 1
fi
echo "${GREEN}✓ 网络连接正常${NC}"

# 更新软件包列表
echo ""
echo "更新软件包列表..."
opkg update

# 安装必要的软件包
echo ""
echo "安装必要的软件包..."

# 检查并安装 node
if ! command -v node >/dev/null 2>&1; then
    echo "安装 Node.js..."
    opkg install node node-npm
    echo "${GREEN}✓ Node.js 安装完成${NC}"
else
    echo "${GREEN}✓ Node.js 已安装${NC}"
fi

# 检查并安装 npm
if ! command -v npm >/dev/null 2>&1; then
    echo "安装 npm..."
    opkg install node-npm
    echo "${GREEN}✓ npm 安装完成${NC}"
else
    echo "${GREEN}✓ npm 已安装${NC}"
fi

# 安装 luci-app-homeproxy (如果不存在)
echo ""
echo "检查 luci-app-homeproxy..."
if opkg list-installed | grep -q luci-app-homeproxy; then
    echo "${GREEN}✓ luci-app-homeproxy 已安装${NC}"
else
    echo "安装 luci-app-homeproxy..."
    if opkg install luci-app-homeproxy 2>/dev/null; then
        echo "${GREEN}✓ luci-app-homeproxy 安装完成${NC}"
    else
        echo "${YELLOW}⚠ luci-app-homeproxy 安装失败，请手动安装${NC}"
    fi
fi

# 升级到 firewall4
echo ""
echo "检查防火墙版本..."
if opkg list-installed | grep -q firewall4; then
    echo "${GREEN}✓ firewall4 已安装${NC}"
elif opkg list-installed | grep -q firewall3; then
    echo "${YELLOW}检测到 firewall3，准备升级到 firewall4...${NC}"
    read -p "是否升级到 firewall4? (y/n): " upgrade_fw
    if [ "$upgrade_fw" = "y" ] || [ "$upgrade_fw" = "Y" ]; then
        opkg remove firewall3
        opkg install firewall4
        /etc/init.d/firewall restart
        echo "${GREEN}✓ firewall4 升级完成${NC}"
    else
        echo "${YELLOW}⚠ 跳过 firewall4 升级${NC}"
    fi
else
    echo "安装 firewall4..."
    opkg install firewall4
    echo "${GREEN}✓ firewall4 安装完成${NC}"
fi

# 安装 nodejs-argo
echo ""
echo "安装 nodejs-argo..."
if npm list -g nodejs-argo >/dev/null 2>&1; then
    echo "${GREEN}✓ nodejs-argo 已安装${NC}"
    read -p "是否更新到最新版本? (y/n): " update_pkg
    if [ "$update_pkg" = "y" ] || [ "$update_pkg" = "Y" ]; then
        npm update -g nodejs-argo
        echo "${GREEN}✓ nodejs-argo 更新完成${NC}"
    fi
else
    npm install -g nodejs-argo
    echo "${GREEN}✓ nodejs-argo 安装完成${NC}"
fi

# 配置环境变量
echo ""
echo "配置环境变量..."
if [ ! -f "/etc/nodejs-argo.env" ]; then
    # 生成随机 UUID
    UUID=$(cat /proc/sys/kernel/random/uuid)
    
    cat > /etc/nodejs-argo.env << EOF
# 基础配置
PORT=3000
ARGO_PORT=8001
UUID=$UUID

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
    echo "${GREEN}✓ 环境变量配置文件已创建: /etc/nodejs-argo.env${NC}"
    echo "${YELLOW}⚠ 请编辑 /etc/nodejs-argo.env 修改配置${NC}"
    echo "${YELLOW}  生成的 UUID: $UUID${NC}"
else
    echo "${GREEN}✓ 环境变量配置文件已存在${NC}"
fi

# 创建系统服务
echo ""
echo "创建系统服务..."
cat > /etc/init.d/nodejs-argo << 'EOF'
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1

start_service() {
    # 加载环境变量
    [ -f /etc/nodejs-argo.env ] && . /etc/nodejs-argo.env
    
    procd_open_instance
    procd_set_param command /usr/bin/npx nodejs-argo
    procd_set_param env PORT="${PORT:-3000}"
    procd_set_param env ARGO_PORT="${ARGO_PORT:-8001}"
    procd_set_param env UUID="${UUID:-89c13786-25aa-4520-b2e7-12cd60fb5202}"
    procd_set_param env CFIP="${CFIP:-cdns.doon.eu.org}"
    procd_set_param env CFPORT="${CFPORT:-443}"
    procd_set_param env NAME="${NAME:-OpenWrt}"
    procd_set_param env SUB_PATH="${SUB_PATH:-sub}"
    procd_set_param env FILE_PATH="${FILE_PATH:-/tmp/nodejs-argo}"
    procd_set_param env ARGO_DOMAIN="${ARGO_DOMAIN}"
    procd_set_param env ARGO_AUTH="${ARGO_AUTH}"
    procd_set_param env NEZHA_SERVER="${NEZHA_SERVER}"
    procd_set_param env NEZHA_PORT="${NEZHA_PORT}"
    procd_set_param env NEZHA_KEY="${NEZHA_KEY}"
    procd_set_param env AUTO_ACCESS="${AUTO_ACCESS:-false}"
    procd_set_param env PROJECT_URL="${PROJECT_URL}"
    procd_set_param env UPLOAD_URL="${UPLOAD_URL}"
    
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    killall node 2>/dev/null || true
}
EOF

chmod +x /etc/init.d/nodejs-argo
echo "${GREEN}✓ 系统服务已创建${NC}"

# 配置防火墙规则
echo ""
echo "配置防火墙规则..."

# 检查规则是否已存在
if ! uci show firewall | grep -q "nodejs_argo_http"; then
    # 添加 HTTP 服务规则
    uci add firewall rule
    uci set firewall.@rule[-1].name='Allow-NodeJS-Argo-HTTP'
    uci set firewall.@rule[-1].src='lan'
    uci set firewall.@rule[-1].dest_port='3000'
    uci set firewall.@rule[-1].proto='tcp'
    uci set firewall.@rule[-1].target='ACCEPT'
    
    # 添加 Argo 隧道规则
    uci add firewall rule
    uci set firewall.@rule[-1].name='Allow-Argo-Tunnel'
    uci set firewall.@rule[-1].src='wan'
    uci set firewall.@rule[-1].dest_port='8001'
    uci set firewall.@rule[-1].proto='tcp'
    uci set firewall.@rule[-1].target='ACCEPT'
    
    uci commit firewall
    /etc/init.d/firewall reload
    echo "${GREEN}✓ 防火墙规则已配置${NC}"
else
    echo "${GREEN}✓ 防火墙规则已存在${NC}"
fi

# 启用并启动服务
echo ""
echo "启用并启动服务..."
/etc/init.d/nodejs-argo enable
/etc/init.d/nodejs-argo start

echo ""
echo "${GREEN}=========================================="
echo "部署完成！"
echo "==========================================${NC}"
echo ""
echo "服务状态:"
/etc/init.d/nodejs-argo status
echo ""
echo "配置信息:"
echo "  - HTTP 服务端口: 3000"
echo "  - Argo 隧道端口: 8001"
echo "  - 订阅地址: http://$(uci get network.lan.ipaddr):3000/sub"
echo "  - 配置文件: /etc/nodejs-argo.env"
echo ""
echo "下一步操作:"
echo "  1. 编辑配置文件: vi /etc/nodejs-argo.env"
echo "  2. 重启服务: /etc/init.d/nodejs-argo restart"
echo "  3. 查看日志: logread | grep nodejs"
echo "  4. 获取订阅: curl http://$(uci get network.lan.ipaddr):3000/sub | base64 -d"
echo ""
echo "配置 luci-app-homeproxy:"
echo "  1. 浏览器打开: http://$(uci get network.lan.ipaddr)"
echo "  2. 进入: 服务 → HomeProxy → 节点管理"
echo "  3. 添加节点，使用上面获取的订阅信息"
echo ""
echo "详细配置指南请参考: OPENWRT_GUIDE.md"
echo ""
EOF
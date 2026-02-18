#!/bin/sh
# nodejs-argo快速安装脚本 for iStoreOS/OpenWRT
# Quick installation script for iStoreOS/OpenWRT

set -e

echo "================================================"
echo "nodejs-argo iStoreOS/OpenWRT 快速安装脚本"
echo "Quick Installation Script"
echo "================================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
   echo "${RED}错误: 此脚本必须以root用户运行${NC}"
   echo "${RED}Error: This script must be run as root${NC}"
   exit 1
fi

# 检测系统类型
echo "${YELLOW}检测系统类型...${NC}"
if [ -f "/etc/openwrt_release" ]; then
    echo "${GREEN}✓ 检测到OpenWRT/iStoreOS系统${NC}"
else
    echo "${YELLOW}⚠ 警告: 未检测到OpenWRT系统，脚本可能无法正常工作${NC}"
    read -p "是否继续？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 步骤1: 更新软件包列表
echo ""
echo "${YELLOW}步骤 1/5: 更新软件包列表...${NC}"
opkg update || {
    echo "${RED}✗ 更新失败，请检查网络连接${NC}"
    exit 1
}
echo "${GREEN}✓ 软件包列表更新完成${NC}"

# 步骤2: 安装Node.js
echo ""
echo "${YELLOW}步骤 2/5: 检查并安装Node.js...${NC}"
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version)
    echo "${GREEN}✓ Node.js已安装 (版本: $NODE_VERSION)${NC}"
else
    echo "正在安装Node.js..."
    opkg install node node-npm || {
        echo "${RED}✗ Node.js安装失败${NC}"
        exit 1
    }
    echo "${GREEN}✓ Node.js安装完成${NC}"
fi

# 步骤3: 安装nodejs-argo
echo ""
echo "${YELLOW}步骤 3/5: 安装nodejs-argo...${NC}"
echo "您希望如何安装nodejs-argo?"
echo "1) npm全局安装 (推荐)"
echo "2) 从GitHub克隆安装"
read -p "请选择 (1/2): " -n 1 -r INSTALL_METHOD
echo

case $INSTALL_METHOD in
    1)
        echo "正在通过npm安装..."
        npm install -g nodejs-argo || {
            echo "${RED}✗ npm安装失败${NC}"
            exit 1
        }
        INSTALL_PATH="/usr/lib/node_modules/nodejs-argo"
        ;;
    2)
        echo "正在从GitHub克隆..."
        mkdir -p /opt
        cd /opt
        if [ -d "nodejs-argo" ]; then
            echo "${YELLOW}⚠ /opt/nodejs-argo已存在，正在更新...${NC}"
            cd nodejs-argo
            git pull || {
                echo "${RED}✗ Git更新失败${NC}"
                exit 1
            }
        else
            git clone https://github.com/h-rbb/nodejs-argo.git || {
                echo "${RED}✗ Git克隆失败${NC}"
                exit 1
            }
            cd nodejs-argo
        fi
        npm install || {
            echo "${RED}✗ npm依赖安装失败${NC}"
            exit 1
        }
        INSTALL_PATH="/opt/nodejs-argo"
        ;;
    *)
        echo "${RED}✗ 无效的选择${NC}"
        exit 1
        ;;
esac
echo "${GREEN}✓ nodejs-argo安装完成${NC}"

# 步骤4: 创建配置文件
echo ""
echo "${YELLOW}步骤 4/5: 创建配置文件...${NC}"

if [ -f "/etc/nodejs-argo.env" ]; then
    echo "${YELLOW}⚠ 配置文件已存在: /etc/nodejs-argo.env${NC}"
    read -p "是否覆盖现有配置？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "保留现有配置"
    else
        CREATE_CONFIG=1
    fi
else
    CREATE_CONFIG=1
fi

if [ "$CREATE_CONFIG" = "1" ]; then
    # 生成随机UUID
    if command -v uuidgen >/dev/null 2>&1; then
        NEW_UUID=$(uuidgen)
    elif [ -f /proc/sys/kernel/random/uuid ]; then
        NEW_UUID=$(cat /proc/sys/kernel/random/uuid)
    else
        # 使用/dev/urandom生成UUID
        NEW_UUID=$(od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}')
    fi
    
    # 验证UUID生成成功
    if [ -z "$NEW_UUID" ] || [ "$NEW_UUID" = "89c13786-25aa-4520-b2e7-12cd60fb5202" ]; then
        echo "${RED}✗ UUID生成失败${NC}"
        echo "${YELLOW}请手动编辑 /etc/nodejs-argo.env 并设置UUID${NC}"
        NEW_UUID="PLEASE-CHANGE-THIS-UUID-$(date +%s)"
    fi
    
    cat > /etc/nodejs-argo.env << EOF
# nodejs-argo配置文件
# 自动生成于: $(date)

# 基础配置
PORT=3000
ARGO_PORT=8001
UUID=$NEW_UUID

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
NAME=

# 订阅配置（可选）
UPLOAD_URL=
PROJECT_URL=
AUTO_ACCESS=false

# 文件路径
FILE_PATH=$INSTALL_PATH/tmp
SUB_PATH=sub

# 内存优化 (适用于1GB RAM设备)
NODE_OPTIONS="--max-old-space-size=256"
EOF
    
    echo "${GREEN}✓ 配置文件创建完成: /etc/nodejs-argo.env${NC}"
    echo "${GREEN}✓ 生成的UUID: $NEW_UUID${NC}"
    echo "${YELLOW}⚠ 请根据需要编辑配置文件: vi /etc/nodejs-argo.env${NC}"
fi

# 步骤5: 配置防火墙
echo ""
echo "${YELLOW}步骤 5/5: 配置防火墙规则...${NC}"
read -p "是否自动配置防火墙规则？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # 检查是否已存在规则
    if ! uci show firewall | grep -q "nodejs-argo"; then
        uci add firewall rule
        uci set firewall.@rule[-1].name='Allow-nodejs-argo-HTTP'
        uci set firewall.@rule[-1].src='wan'
        uci set firewall.@rule[-1].dest_port='3000'
        uci set firewall.@rule[-1].target='ACCEPT'
        uci set firewall.@rule[-1].proto='tcp'
        
        uci add firewall rule
        uci set firewall.@rule[-1].name='Allow-nodejs-argo-Argo'
        uci set firewall.@rule[-1].src='wan'
        uci set firewall.@rule[-1].dest_port='8001'
        uci set firewall.@rule[-1].target='ACCEPT'
        uci set firewall.@rule[-1].proto='tcp'
        
        uci commit firewall
        /etc/init.d/firewall restart
        
        echo "${GREEN}✓ 防火墙规则配置完成${NC}"
    else
        echo "${YELLOW}⚠ 防火墙规则已存在${NC}"
    fi
else
    echo "跳过防火墙配置"
fi

# 安装init.d服务脚本
echo ""
echo "${YELLOW}安装系统服务...${NC}"
if [ -f "$INSTALL_PATH/scripts/nodejs-argo.init" ]; then
    cp "$INSTALL_PATH/scripts/nodejs-argo.init" /etc/init.d/nodejs-argo
    chmod +x /etc/init.d/nodejs-argo
    echo "${GREEN}✓ 系统服务安装完成${NC}"
elif [ -f "$(dirname "$0")/scripts/nodejs-argo.init" ]; then
    cp "$(dirname "$0")/scripts/nodejs-argo.init" /etc/init.d/nodejs-argo
    chmod +x /etc/init.d/nodejs-argo
    echo "${GREEN}✓ 系统服务安装完成${NC}"
else
    echo "${YELLOW}⚠ 未找到init.d脚本，请手动配置服务${NC}"
fi

# 完成安装
echo ""
echo "================================================"
echo "${GREEN}✓ nodejs-argo安装完成！${NC}"
echo "================================================"
echo ""
echo "后续步骤:"
echo ""
echo "1. 编辑配置文件（可选）:"
echo "   ${YELLOW}vi /etc/nodejs-argo.env${NC}"
echo ""
echo "2. 启动服务:"
echo "   ${YELLOW}/etc/init.d/nodejs-argo start${NC}"
echo ""
echo "3. 设置开机自启:"
echo "   ${YELLOW}/etc/init.d/nodejs-argo enable${NC}"
echo ""
echo "4. 检查服务状态:"
echo "   ${YELLOW}/etc/init.d/nodejs-argo status${NC}"
echo ""
echo "5. 访问订阅地址:"
echo "   ${YELLOW}http://$(uci get network.lan.ipaddr 2>/dev/null || echo "ROUTER-IP"):3000/sub${NC}"
echo ""
echo "详细文档: https://github.com/h-rbb/nodejs-argo/blob/main/docs/iStoreOS-deployment.md"
echo ""
echo "================================================"
echo "感谢使用nodejs-argo！"
echo "================================================"

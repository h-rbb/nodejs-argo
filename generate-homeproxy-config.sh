#!/bin/sh
# HomeProxy 配置生成脚本
# 自动从 nodejs-argo 获取配置信息并生成 homeproxy 兼容的配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "${BLUE}=========================================="
echo "HomeProxy 配置生成脚本"
echo "==========================================${NC}"
echo ""

# 加载环境变量
if [ -f "/etc/nodejs-argo.env" ]; then
    . /etc/nodejs-argo.env
    echo "${GREEN}✓ 已加载环境变量${NC}"
else
    echo "${RED}错误: 未找到配置文件 /etc/nodejs-argo.env${NC}"
    exit 1
fi

# 检查服务是否运行
if ! pgrep -f "nodejs-argo" > /dev/null; then
    echo "${YELLOW}⚠ nodejs-argo 服务未运行，正在启动...${NC}"
    /etc/init.d/nodejs-argo start
    sleep 5
fi

# 获取 Argo 域名
echo ""
echo "获取 Argo 隧道域名..."

ARGO_DOMAIN_ACTUAL=""
if [ -n "$ARGO_DOMAIN" ] && [ -n "$ARGO_AUTH" ]; then
    ARGO_DOMAIN_ACTUAL="$ARGO_DOMAIN"
    echo "${GREEN}✓ 使用固定隧道域名: $ARGO_DOMAIN_ACTUAL${NC}"
else
    # 从日志中提取临时隧道域名
    sleep 3
    if [ -f "${FILE_PATH:-/tmp/nodejs-argo}/boot.log" ]; then
        ARGO_DOMAIN_ACTUAL=$(grep -oP 'https://\K[^/]*trycloudflare\.com' "${FILE_PATH:-/tmp/nodejs-argo}/boot.log" | head -1)
        if [ -n "$ARGO_DOMAIN_ACTUAL" ]; then
            echo "${GREEN}✓ 获取到临时隧道域名: $ARGO_DOMAIN_ACTUAL${NC}"
        else
            echo "${YELLOW}⚠ 未能从日志获取域名，请稍后重试${NC}"
            exit 1
        fi
    else
        echo "${RED}错误: 未找到 boot.log 文件${NC}"
        exit 1
    fi
fi

# 检查必要参数
if [ -z "$UUID" ]; then
    echo "${RED}错误: UUID 未配置${NC}"
    exit 1
fi

CFIP=${CFIP:-cdns.doon.eu.org}
CFPORT=${CFPORT:-443}

echo ""
echo "配置信息:"
echo "  UUID: $UUID"
echo "  CFIP: $CFIP"
echo "  CFPORT: $CFPORT"
echo "  Argo Domain: $ARGO_DOMAIN_ACTUAL"
echo ""

# 生成配置文件
CONFIG_DIR="/etc/homeproxy"
CONFIG_FILE="$CONFIG_DIR/nodejs-argo-nodes.json"

mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_FILE" << EOF
{
  "nodes": [
    {
      "tag": "nodejs-argo-vless",
      "type": "vless",
      "server": "$CFIP",
      "server_port": $CFPORT,
      "uuid": "$UUID",
      "flow": "",
      "transport": {
        "type": "ws",
        "path": "/vless-argo?ed=2560",
        "headers": {
          "Host": "$ARGO_DOMAIN_ACTUAL"
        }
      },
      "tls": {
        "enabled": true,
        "server_name": "$ARGO_DOMAIN_ACTUAL",
        "insecure": false,
        "utls": {
          "enabled": true,
          "fingerprint": "firefox"
        }
      }
    },
    {
      "tag": "nodejs-argo-vmess",
      "type": "vmess",
      "server": "$CFIP",
      "server_port": $CFPORT,
      "uuid": "$UUID",
      "security": "none",
      "alter_id": 0,
      "transport": {
        "type": "ws",
        "path": "/vmess-argo?ed=2560",
        "headers": {
          "Host": "$ARGO_DOMAIN_ACTUAL"
        }
      },
      "tls": {
        "enabled": true,
        "server_name": "$ARGO_DOMAIN_ACTUAL",
        "insecure": false
      }
    },
    {
      "tag": "nodejs-argo-trojan",
      "type": "trojan",
      "server": "$CFIP",
      "server_port": $CFPORT,
      "password": "$UUID",
      "transport": {
        "type": "ws",
        "path": "/trojan-argo?ed=2560",
        "headers": {
          "Host": "$ARGO_DOMAIN_ACTUAL"
        }
      },
      "tls": {
        "enabled": true,
        "server_name": "$ARGO_DOMAIN_ACTUAL",
        "insecure": false,
        "utls": {
          "enabled": true,
          "fingerprint": "firefox"
        }
      }
    }
  ]
}
EOF

echo "${GREEN}✓ 配置文件已生成: $CONFIG_FILE${NC}"
echo ""

# 生成订阅链接
LAN_IP=$(uci get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")
SUB_URL="http://${LAN_IP}:${PORT:-3000}/${SUB_PATH:-sub}"

echo "${BLUE}=========================================="
echo "配置信息"
echo "==========================================${NC}"
echo ""
echo "订阅地址:"
echo "  ${GREEN}$SUB_URL${NC}"
echo ""
echo "节点信息 (VLESS):"
echo "  服务器: $CFIP"
echo "  端口: $CFPORT"
echo "  UUID: $UUID"
echo "  传输: WebSocket"
echo "  路径: /vless-argo?ed=2560"
echo "  TLS: 启用"
echo "  SNI: $ARGO_DOMAIN_ACTUAL"
echo "  指纹: firefox"
echo ""
echo "节点信息 (VMess):"
echo "  服务器: $CFIP"
echo "  端口: $CFPORT"
echo "  UUID: $UUID"
echo "  额外ID: 0"
echo "  传输: WebSocket"
echo "  路径: /vmess-argo?ed=2560"
echo "  TLS: 启用"
echo "  SNI: $ARGO_DOMAIN_ACTUAL"
echo ""
echo "节点信息 (Trojan):"
echo "  服务器: $CFIP"
echo "  端口: $CFPORT"
echo "  密码: $UUID"
echo "  传输: WebSocket"
echo "  路径: /trojan-argo?ed=2560"
echo "  TLS: 启用"
echo "  SNI: $ARGO_DOMAIN_ACTUAL"
echo "  指纹: firefox"
echo ""

# 生成 UCI 配置命令
echo "${BLUE}=========================================="
echo "UCI 配置命令 (可选)"
echo "==========================================${NC}"
echo ""
echo "您可以使用以下命令通过 UCI 直接配置 HomeProxy:"
echo ""
echo "${YELLOW}# VLESS 节点${NC}"
cat << 'UCIEOF'
uci set homeproxy.nodejs_vless=node
uci set homeproxy.nodejs_vless.type='vless'
uci set homeproxy.nodejs_vless.label='NodeJS-Argo-VLESS'
UCIEOF
echo "uci set homeproxy.nodejs_vless.address='$CFIP'"
echo "uci set homeproxy.nodejs_vless.port='$CFPORT'"
echo "uci set homeproxy.nodejs_vless.uuid='$UUID'"
cat << 'UCIEOF'
uci set homeproxy.nodejs_vless.transport='ws'
uci set homeproxy.nodejs_vless.ws_path='/vless-argo?ed=2560'
UCIEOF
echo "uci set homeproxy.nodejs_vless.ws_host='$ARGO_DOMAIN_ACTUAL'"
cat << 'UCIEOF'
uci set homeproxy.nodejs_vless.tls='1'
UCIEOF
echo "uci set homeproxy.nodejs_vless.tls_sni='$ARGO_DOMAIN_ACTUAL'"
cat << 'UCIEOF'
uci set homeproxy.nodejs_vless.fingerprint='firefox'
uci commit homeproxy
UCIEOF
echo ""

# 显示下一步操作
echo "${BLUE}=========================================="
echo "下一步操作"
echo "==========================================${NC}"
echo ""
echo "1. 在浏览器中打开 LuCI 界面:"
echo "   ${GREEN}http://${LAN_IP}${NC}"
echo ""
echo "2. 导航到 HomeProxy:"
echo "   服务 → HomeProxy → 节点管理"
echo ""
echo "3. 添加节点:"
echo "   - 方式1: 使用订阅地址 (推荐)"
echo "     在订阅管理中添加: $SUB_URL"
echo ""
echo "   - 方式2: 手动添加节点"
echo "     使用上面显示的节点信息手动填写"
echo ""
echo "   - 方式3: 使用 UCI 命令"
echo "     复制上面的 UCI 命令并执行"
echo ""
echo "4. 启用节点并启动 HomeProxy 服务"
echo ""
echo "详细配置指南请参考: OPENWRT_GUIDE.md"
echo ""

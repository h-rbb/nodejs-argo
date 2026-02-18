# Scripts for iStoreOS/OpenWRT Deployment

This directory contains scripts and configuration files for deploying nodejs-argo on iStoreOS/OpenWRT routers.

## Files

### install-istoreos.sh
Interactive installation script for quick setup on iStoreOS/OpenWRT systems.

**Features:**
- System detection and validation
- Automatic Node.js installation
- Choice between npm and git installation methods
- Automatic configuration file generation
- Firewall rule configuration
- Service script installation

**Usage:**
```bash
# Download and run directly
wget -O - https://raw.githubusercontent.com/h-rbb/nodejs-argo/main/scripts/install-istoreos.sh | sh

# Or download first, then run
wget https://raw.githubusercontent.com/h-rbb/nodejs-argo/main/scripts/install-istoreos.sh
chmod +x install-istoreos.sh
./install-istoreos.sh
```

### nodejs-argo.init
OpenWRT init.d service script for automatic startup and management.

**Features:**
- procd-based service management
- Automatic configuration loading
- Support for both npm and git installation methods
- Environment variable management
- Automatic restart on failure

**Installation:**
```bash
# Copy to init.d directory
cp nodejs-argo.init /etc/init.d/nodejs-argo
chmod +x /etc/init.d/nodejs-argo

# Enable and start service
/etc/init.d/nodejs-argo enable
/etc/init.d/nodejs-argo start
```

**Usage:**
```bash
/etc/init.d/nodejs-argo start    # Start service
/etc/init.d/nodejs-argo stop     # Stop service
/etc/init.d/nodejs-argo restart  # Restart service
/etc/init.d/nodejs-argo status   # Check status
/etc/init.d/nodejs-argo enable   # Enable auto-start
/etc/init.d/nodejs-argo disable  # Disable auto-start
```

### nodejs-argo.env.sample
Sample configuration file with detailed comments.

**Installation:**
```bash
# Copy to system location
cp nodejs-argo.env.sample /etc/nodejs-argo.env

# Edit configuration
vi /etc/nodejs-argo.env
```

**Important Settings:**
- `UUID`: Change to your own UUID (required)
- `PORT`: HTTP service port (default: 3000)
- `ARGO_PORT`: Argo tunnel port (default: 8001)
- `NAME`: Node name prefix
- `ARGO_DOMAIN` & `ARGO_AUTH`: For fixed tunnels (optional)
- `NEZHA_*`: Nezha monitoring settings (optional)

## Quick Start

### Method 1: One-line Installation (Recommended)

```bash
wget -O - https://raw.githubusercontent.com/h-rbb/nodejs-argo/main/scripts/install-istoreos.sh | sh
```

### Method 2: Manual Installation

1. **Install Node.js:**
   ```bash
   opkg update
   opkg install node node-npm
   ```

2. **Install nodejs-argo:**
   ```bash
   npm install -g nodejs-argo
   ```

3. **Create configuration:**
   ```bash
   cp nodejs-argo.env.sample /etc/nodejs-argo.env
   vi /etc/nodejs-argo.env  # Edit as needed
   ```

4. **Install service:**
   ```bash
   cp nodejs-argo.init /etc/init.d/nodejs-argo
   chmod +x /etc/init.d/nodejs-argo
   /etc/init.d/nodejs-argo enable
   /etc/init.d/nodejs-argo start
   ```

5. **Configure firewall:**
   ```bash
   uci add firewall rule
   uci set firewall.@rule[-1].name='Allow-nodejs-argo-HTTP'
   uci set firewall.@rule[-1].src='wan'
   uci set firewall.@rule[-1].dest_port='3000'
   uci set firewall.@rule[-1].target='ACCEPT'
   uci set firewall.@rule[-1].proto='tcp'
   uci commit firewall
   /etc/init.d/firewall restart
   ```

## Supported Devices

- ✅ JDCloud AX1800 Pro
- ✅ Xiaomi AX1800
- ✅ Redmi AX6
- ✅ And other OpenWRT/iStoreOS compatible devices with:
  - Node.js support
  - At least 512MB RAM (1GB+ recommended)
  - 100MB+ free storage

## System Requirements

- **OS**: iStoreOS R24.05.19+ or OpenWRT 22.03+
- **RAM**: 512MB minimum, 1GB+ recommended
- **Storage**: 100MB+ free space
- **Node.js**: 14.0 or higher

## Integration

### With luci-app-homeproxy

1. Start nodejs-argo service
2. Access router web interface
3. Go to Services → HomeProxy
4. Add subscription: `http://127.0.0.1:3000/sub`
5. Update subscription and select nodes

### With Firewall4

The scripts automatically configure Firewall4 rules. Manual configuration:

```bash
# Add rules via UCI
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-nodejs-argo-HTTP'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='3000'
uci set firewall.@rule[-1].target='ACCEPT'
uci set firewall.@rule[-1].proto='tcp'
uci commit firewall
/etc/init.d/firewall restart
```

## Troubleshooting

### Service won't start

```bash
# Check logs
logread | grep nodejs-argo

# Check Node.js
node --version
npm --version

# Check installation
ls -la /usr/lib/node_modules/nodejs-argo/
# or
ls -la /opt/nodejs-argo/

# Test manually
cd /opt/nodejs-argo && node index.js
```

### Port conflict

```bash
# Check port usage
netstat -tulpn | grep -E '(3000|8001)'

# Change ports in config
vi /etc/nodejs-argo.env
# Update PORT and ARGO_PORT
```

### Memory issues

```bash
# Check memory
free -m

# Reduce memory limit
vi /etc/nodejs-argo.env
# Add or modify: NODE_OPTIONS="--max-old-space-size=128"
```

## Documentation

- 📖 [Complete Deployment Guide](../docs/iStoreOS-deployment.md)
- 📝 [Quick Reference](../docs/quick-reference.md)
- 🏠 [Main README](../README.md)

## Support

- 🐛 Issues: https://github.com/h-rbb/nodejs-argo/issues
- 💬 Telegram: https://t.me/eooceu

## License

GPL 3.0 - Personal use only, commercial use prohibited.

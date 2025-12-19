#!/bin/bash
# install-agent-frpc-synology.sh - Install CheckMK agent + FRPC on Synology NAS
# Configures CheckMK agent and FRP client for Synology DSM

set -euo pipefail

# Configuration
FRPS_SERVER="${FRPS_SERVER:-frp.example.com}"
FRPS_PORT="${FRPS_PORT:-7000}"
FRPC_TOKEN="${FRPC_TOKEN:-your_token_here}"
CHECKMK_SERVER="${CHECKMK_SERVER:-checkmk.example.com}"
HOSTNAME="${HOSTNAME:-$(hostname)}"

echo "=== CheckMK Agent + FRPC Installation for Synology ==="
echo ""

# Check if running on Synology
if [[ ! -f /etc/synoinfo.conf ]]; then
    echo "ERROR: This script is designed for Synology NAS systems"
    exit 1
fi

# Install CheckMK agent
echo "1. Installing CheckMK agent..."
mkdir -p /volume1/@appstore/checkmk/agent
cd /volume1/@appstore/checkmk/agent

# Download agent
wget -q "http://${CHECKMK_SERVER}/monitoring/check_mk/agents/check_mk_agent.linux" -O check_mk_agent
chmod +x check_mk_agent

# Create xinetd service for DSM 7+
if [[ -d /usr/local/etc/services.d ]]; then
    # DSM 7 style
    mkdir -p /usr/local/etc/services.d
    cat > /usr/local/etc/services.d/check_mk.conf <<EOF
[check_mk]
title = CheckMK Agent
desc = CheckMK Monitoring Agent
author = CheckMK
icon = /usr/syno/synoman/webman/modules/CheckMK/checkmk.png
port_forward = yes
dst.ports = 6556/tcp
EOF
fi

# Create systemd service
cat > /usr/lib/systemd/system/check_mk.socket <<EOF
[Unit]
Description=CheckMK Agent Socket

[Socket]
ListenStream=6556
Accept=yes

[Install]
WantedBy=sockets.target
EOF

cat > /usr/lib/systemd/system/check_mk@.service <<EOF
[Unit]
Description=CheckMK Agent

[Service]
ExecStart=/volume1/@appstore/checkmk/agent/check_mk_agent
StandardInput=socket
EOF

# Enable and start
systemctl daemon-reload
systemctl enable check_mk.socket
systemctl start check_mk.socket

echo "✓ CheckMK agent installed on port 6556"

# Install FRPC
echo ""
echo "2. Installing FRP Client..."
mkdir -p /volume1/@appstore/frpc
cd /volume1/@appstore/frpc

# Download FRPC
FRPC_VERSION="0.52.3"
wget -q "https://github.com/fatedier/frp/releases/download/v${FRPC_VERSION}/frp_${FRPC_VERSION}_linux_amd64.tar.gz"
tar -xzf "frp_${FRPC_VERSION}_linux_amd64.tar.gz"
mv "frp_${FRPC_VERSION}_linux_amd64/frpc" .
chmod +x frpc
rm -rf "frp_${FRPC_VERSION}_linux_amd64"*

# Create config
cat > /volume1/@appstore/frpc/frpc.ini <<EOF
[common]
server_addr = ${FRPS_SERVER}
server_port = ${FRPS_PORT}
auth_method = token
auth_token = ${FRPC_TOKEN}

[checkmk-${HOSTNAME}]
type = tcp
local_ip = 127.0.0.1
local_port = 6556
remote_port = 0
EOF

# Create systemd service
cat > /usr/lib/systemd/system/frpc.service <<EOF
[Unit]
Description=FRP Client
After=network.target

[Service]
Type=simple
WorkingDirectory=/volume1/@appstore/frpc
ExecStart=/volume1/@appstore/frpc/frpc -c /volume1/@appstore/frpc/frpc.ini
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
systemctl daemon-reload
systemctl enable frpc
systemctl start frpc

echo "✓ FRP Client installed and started"
echo ""
echo "=== Installation Complete ==="
echo "Agent listening on: 127.0.0.1:6556"
echo "FRP Server: ${FRPS_SERVER}:${FRPS_PORT}"
echo "Configure CheckMK to use the FRP tunnel port"

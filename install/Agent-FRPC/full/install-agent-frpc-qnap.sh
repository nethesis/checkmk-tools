#!/bin/bash
# install-agent-frpc-qnap.sh - Install CheckMK agent + FRPC on QNAP NAS
# Configures CheckMK agent and FRP client for QNAP systems

set -euo pipefail

# Configuration
FRPS_SERVER="${FRPS_SERVER:-frp.example.com}"
FRPS_PORT="${FRPS_PORT:-7000}"
FRPC_TOKEN="${FRPC_TOKEN:-your_token_here}"
CHECKMK_SERVER="${CHECKMK_SERVER:-checkmk.example.com}"
HOSTNAME="${HOSTNAME:-$(hostname)}"

echo "=== CheckMK Agent + FRPC Installation for QNAP ==="
echo ""

# Check if running on QNAP
if [[ ! -f /etc/config/qpkg.conf ]]; then
    echo "ERROR: This script is designed for QNAP NAS systems"
    exit 1
fi

# Install CheckMK agent
echo "1. Installing CheckMK agent..."
mkdir -p /opt/checkmk/agent
cd /opt/checkmk/agent

# Download agent
wget -q "http://${CHECKMK_SERVER}/monitoring/check_mk/agents/check_mk_agent.linux" -O check_mk_agent
chmod +x check_mk_agent

# Create xinetd service
mkdir -p /etc/xinetd.d
cat > /etc/xinetd.d/check_mk <<EOF
service check_mk
{
    type           = UNLISTED
    port           = 6556
    socket_type    = stream
    protocol       = tcp
    wait           = no
    user           = admin
    server         = /opt/checkmk/agent/check_mk_agent
    disable        = no
}
EOF

# Restart xinetd
/etc/init.d/xinetd.sh restart

echo "✓ CheckMK agent installed on port 6556"

# Install FRPC
echo ""
echo "2. Installing FRP Client..."
mkdir -p /opt/frpc
cd /opt/frpc

# Download FRPC (adjust version as needed)
FRPC_VERSION="0.52.3"
wget -q "https://github.com/fatedier/frp/releases/download/v${FRPC_VERSION}/frp_${FRPC_VERSION}_linux_amd64.tar.gz"
tar -xzf "frp_${FRPC_VERSION}_linux_amd64.tar.gz"
mv "frp_${FRPC_VERSION}_linux_amd64/frpc" .
chmod +x frpc
rm -rf "frp_${FRPC_VERSION}_linux_amd64"*

# Create FRPC config
cat > /opt/frpc/frpc.ini <<EOF
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

# Create startup script
cat > /opt/frpc/frpc.sh <<'SCRIPT'
#!/bin/bash
cd /opt/frpc
./frpc -c frpc.ini &
SCRIPT

chmod +x /opt/frpc/frpc.sh

# Add to autostart
echo "/opt/frpc/frpc.sh" >> /etc/config/autorun.sh

# Start FRPC
/opt/frpc/frpc.sh

echo "✓ FRP Client installed and started"
echo ""
echo "=== Installation Complete ==="
echo "Agent listening on: 127.0.0.1:6556"
echo "FRP Server: ${FRPS_SERVER}:${FRPS_PORT}"
echo "Configure CheckMK to use the FRP tunnel port"

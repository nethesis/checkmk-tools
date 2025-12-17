#!/usr/bin/env bash

set -euo pipefail

SOCKET_FILE="/etc/systemd/system/check-mk-agent-plain.socket"
SERVICE_FILE="/etc/systemd/system/check-mk-agent-plain@.service"

force=0
if [[ "${1:-}" == "--force" ]]; then
    force=1
fi

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "ERROR: run as root" >&2
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
    echo "ERROR: systemctl not found (systemd required)" >&2
    exit 1
fi

if [[ $force -eq 0 ]] && { [[ -f "$SOCKET_FILE" ]] || [[ -f "$SERVICE_FILE" ]]; }; then
    echo "ERROR: plain socket/service already exists:" >&2
    [[ -f "$SOCKET_FILE" ]] && echo "- $SOCKET_FILE" >&2
    [[ -f "$SERVICE_FILE" ]] && echo "- $SERVICE_FILE" >&2
    echo "Re-run with --force to overwrite." >&2
    exit 1
fi

echo "Disabling TLS agent controller (cmk-agent-ctl-daemon)..."
systemctl stop cmk-agent-ctl-daemon 2>/dev/null || true
systemctl disable cmk-agent-ctl-daemon 2>/dev/null || true

echo "Disabling default systemd socket (check-mk-agent.socket)..."
systemctl stop check-mk-agent.socket 2>/dev/null || true
systemctl disable check-mk-agent.socket 2>/dev/null || true

echo "Writing systemd units for plain agent on TCP/6556..."
cat >"$SOCKET_FILE" <<'EOF'
[Unit]
Description=Checkmk Agent (plain TCP 6556)
Documentation=https://docs.checkmk.com/latest/en/agent_linux.html

[Socket]
ListenStream=6556
Accept=yes

[Install]
WantedBy=sockets.target
EOF

cat >"$SERVICE_FILE" <<'EOF'
[Unit]
Description=Checkmk Agent (plain TCP 6556) connection
Documentation=https://docs.checkmk.com/latest/en/agent_linux.html

[Service]
ExecStart=/usr/bin/check_mk_agent
StandardInput=socket
StandardOutput=socket
EOF

echo "Reloading systemd..."
systemctl daemon-reload

echo "Enabling and starting check-mk-agent-plain.socket..."
systemctl enable --now check-mk-agent-plain.socket

echo "Done. Verify with:"
echo "  ss -tlnp | grep 6556"
echo "  nc 127.0.0.1 6556 | head"

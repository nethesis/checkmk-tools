#!/usr/bin/env bash

set -euo pipefail

# Lista degli host (hostname o IP)
HOSTS=("marziodemo" "proxmox01" "rocky01" "ns8demo")

# Utente SSH (deve poter usare systemctl; tipicamente root)
USER="root"

force=0
if [[ "${1:-}" == "--force" ]]; then
    force=1
fi

REMOTE_SCRIPT=$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SOCKET_FILE="/etc/systemd/system/check-mk-agent-plain.socket"
SERVICE_FILE="/etc/systemd/system/check-mk-agent-plain@.service"

force="${FORCE:-0}"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "ERROR: run as root" >&2
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
    echo "ERROR: systemctl not found (systemd required)" >&2
    exit 1
fi

if [[ "$force" != "1" ]] && { [[ -f "$SOCKET_FILE" ]] || [[ -f "$SERVICE_FILE" ]]; }; then
    echo "Plain unit already present; skipping."
    exit 0
fi

echo "Disabling TLS agent controller (cmk-agent-ctl-daemon)..."
systemctl stop cmk-agent-ctl-daemon 2>/dev/null || true
systemctl disable cmk-agent-ctl-daemon 2>/dev/null || true

echo "Disabling default systemd socket (check-mk-agent.socket)..."
systemctl stop check-mk-agent.socket 2>/dev/null || true
systemctl disable check-mk-agent.socket 2>/dev/null || true

echo "Writing systemd units for plain agent on TCP/6556..."
cat >"$SOCKET_FILE" <<'UNIT'
[Unit]
Description=Checkmk Agent (plain TCP 6556)
Documentation=https://docs.checkmk.com/latest/en/agent_linux.html

[Socket]
ListenStream=6556
Accept=yes

[Install]
WantedBy=sockets.target
UNIT

cat >"$SERVICE_FILE" <<'UNIT'
[Unit]
Description=Checkmk Agent (plain TCP 6556) connection
Documentation=https://docs.checkmk.com/latest/en/agent_linux.html

[Service]
ExecStart=/usr/bin/check_mk_agent
StandardInput=socket
StandardOutput=socket
UNIT

echo "Reloading systemd..."
systemctl daemon-reload

echo "Enabling and starting check-mk-agent-plain.socket..."
systemctl enable --now check-mk-agent-plain.socket

echo "Host configured."
if [[ -x /usr/bin/check_mk_agent ]]; then
    /usr/bin/check_mk_agent | head -n 5 || true
fi
EOF
)

for h in "${HOSTS[@]}"; do
    echo "============================"
    echo "Configuring ${h}"
    echo "============================"
    ssh -o BatchMode=yes -o ConnectTimeout=10 "${USER}@${h}" "FORCE=${force} bash -s" <<<"$REMOTE_SCRIPT"
    echo
done

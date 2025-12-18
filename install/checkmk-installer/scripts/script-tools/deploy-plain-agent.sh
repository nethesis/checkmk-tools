#!/bin/bash
# ================================================
# Deploy Checkmk Agent in modalitaa Plain TCP 6556
# Compatibile con Checkmk Raw Edition
# ================================================set -e
SOCKET_FILE="/etc/systemd/system/check-mk-agent-plain.socket"
SERVICE_FILE="/etc/systemd/system/check-mk-agent-plain@.service"
FORCE=0
if [[ "$1" == "--force" ]]; then
    FORCE=1    
echo "oiaA  Modalitaa FORCE attiva: eventuali file esistenti saranno sovrascritti."fi
# --- Check esistenza ---if [[ $FORCE -eq 0 ]] && ([[ -f "$SOCKET_FILE" ]] || [[ -f "$SERVICE_FILE" ]]); then
    echo "oiaA  ATTENZIONE: esiste giaa un file service/socket plain:"    [[ -f "$SOCKET_FILE" ]] && 
echo " - $SOCKET_FILE"    [[ -f "$SERVICE_FILE" ]] && 
echo " - $SERVICE_FILE"    
echo "Usa $0 --force se vuoi sovrascriverli."
    exit 1
fi echo "OCyOC Disabilito agent controller TLS (cmk-agent-ctl-daemon)..."systemctl stop cmk-agent-ctl-daemon 2>/dev/null || truesystemctl disable cmk-agent-ctl-daemon 2>/dev/null || true
echo "OCyOC Disabilito il socket systemd standard..."systemctl stop check-mk-agent.socket 2>/dev/null || truesystemctl disable check-mk-agent.socket 2>/dev/null || true
echo "OCyOC Creo unit systemd per agent plain..."cat >"$SOCKET_FILE" <<'EOF'
[Unit]Description=Checkmk Agent (TCP 6556 plain)Documentation=https://docs.checkmk.com/latest/en/agent_linux.html[Socket]ListenStream=6556Accept=yes[Install]WantedBy=sockets.targetEOFcat >"$SERVICE_FILE" <<'EOF'
[Unit]Description=Checkmk Agent (TCP 6556 plain) connectionDocumentation=https://docs.checkmk.com/latest/en/agent_linux.html[Service]ExecStart=-/usr/bin/check_mk_agentStandardInput=socketEOF
echo "OCyOC Ricarico systemd..."systemctl daemon-reload
echo "OCyOC Abilito e avvio il nuovo socket..."systemctl enable --now check-mk-agent-plain.socket
echo "ooOCa Completato. Verifica con:"
echo "   ss -tlnp | grep 6556"
echo "   nc 127.0.0.1 6556 | head"

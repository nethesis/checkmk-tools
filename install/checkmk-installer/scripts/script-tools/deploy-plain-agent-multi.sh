#!/bin/bash
# =====================================================
# Deploy Checkmk Agent (plain TCP 6556) su pia host via SSH
# Compatibile con Checkmk Raw Edition
# =====================================================
# Lista degli host (hostname o IP)
HOSTS=("marziodemo" "proxmox01" "rocky01" "ns8demo")
# Utente SSH (deve avere sudo/root)
USER="root"
# Flag 
FORCE=0
if [[ "$1" == "--force" ]]; then
    FORCE=1    
echo "oiaA Modalitaa FORCE attiva: eventuali file esistenti saranno sovrascritti."fi
# Script remoto che saraa eseguito su ciascun hostread -r -d '' REMOTE_SCRIPT <<'EOF'set -e
SOCKET_FILE="/etc/systemd/system/check-mk-agent-plain.socket"
SERVICE_FILE="/etc/systemd/system/check-mk-agent-plain@.service"
if [[ $FORCE -eq 0 ]] && ([[ -f "$SOCKET_FILE" || -f "$SERVICE_FILE" ]]); then
    echo "oiaA  Unit plain giaa presente, skip..."
    exit 0
fi echo "OCyOC Disabilito agent controller TLS..."systemctl stop cmk-agent-ctl-daemon 2>/dev/null || truesystemctl disable cmk-agent-ctl-daemon 2>/dev/null || true
echo "OCyOC Disabilito il socket systemd standard..."systemctl stop check-mk-agent.socket 2>/dev/null || truesystemctl disable check-mk-agent.socket 2>/dev/null || true
echo "OCyOC Creo unit systemd per agent plain..."cat >"$SOCKET_FILE" <<EOT
[Unit]Description=Checkmk Agent (TCP 6556 plain)Documentation=https://docs.checkmk.com/latest/en/agent_linux.html[Socket]ListenStream=6556Accept=yes[Install]WantedBy=sockets.targetEOTcat >"$SERVICE_FILE" <<EOT
[Unit]Description=Checkmk Agent (TCP 6556 plain) connectionDocumentation=https://docs.checkmk.com/latest/en/agent_linux.html[Service]ExecStart=-/usr/bin/check_mk_agentStandardInput=socketEOT
echo "OCyOC Ricarico systemd..."systemctl daemon-reload
echo "OCyOC Abilito e avvio il nuovo socket..."systemctl enable --now check-mk-agent-plain.socket
echo "ooOCa Host configurato. Test locale:"/usr/bin/check_mk_agent | head -n 5EOF
# Loop sugli hostfor h in "${HOSTS[@]}"; do  
echo "============================"  
echo "oiA  Configuro $h"  
echo "============================"  ssh -o BatchMode=yes -o ConnectTimeout=10 ${USER}@${h} \    "
FORCE=${FORCE} bash -s" <<< "$REMOTE_SCRIPT"  
echo ""done


#!/bin/bash
/bin/bash
# =====================================================
# Deploy Checkmk Agent (plain TCP 6556) su pi├â┬╣ host via SSH
# Compatibile con Checkmk Raw Edition
# =====================================================
# Lista degli host (hostname o IP)
HOSTS=("marziodemo" "proxmox01" "rocky01" "ns8demo")
# Utente SSH (deve avere sudo/root)
USER="root"
# Flag 
FORCEFORCE=0if [[ "$1" == "--force" ]]; then    
FORCE=1    
echo "├ó┼í┬á├»┬©┬Å Modalit├â┬á FORCE attiva: eventuali file esistenti saranno sovrascritti."fi
# Script remoto che sar├â┬á eseguito su ciascun hostread -r -d '' REMOTE_SCRIPT <<'EOF'set -e
SOCKET_FILE="/etc/systemd/system/check-mk-agent-plain.socket"
SERVICE_FILE="/etc/systemd/system/check-mk-agent-plain@.service"if [[ $FORCE -eq 0 ]] && ([[ -f "$SOCKET_FILE" || -f "$SERVICE_FILE" ]]); then  
echo "├ó┼í┬á├»┬©┬Å  Unit plain gi├â┬á presente, skip..."  exit 0fi
echo "├░┼©ÔÇÿÔÇ░ Disabilito agent controller TLS..."systemctl stop cmk-agent-ctl-daemon 2>/dev/null || truesystemctl disable cmk-agent-ctl-daemon 2>/dev/null || true
echo "├░┼©ÔÇÿÔÇ░ Disabilito il socket systemd standard..."systemctl stop check-mk-agent.socket 2>/dev/null || truesystemctl disable check-mk-agent.socket 2>/dev/null || true
echo "├░┼©ÔÇÿÔÇ░ Creo unit systemd per agent plain..."cat >"$SOCKET_FILE" <<EOT[Unit]Description=Checkmk Agent (TCP 6556 plain)Documentation=https://docs.checkmk.com/latest/en/agent_linux.html[Socket]ListenStream=6556Accept=yes[Install]WantedBy=sockets.targetEOTcat >"$SERVICE_FILE" <<EOT[Unit]Description=Checkmk Agent (TCP 6556 plain) connectionDocumentation=https://docs.checkmk.com/latest/en/agent_linux.html[Service]ExecStart=-/usr/bin/check_mk_agentStandardInput=socketEOT
echo "├░┼©ÔÇÿÔÇ░ Ricarico systemd..."systemctl daemon-reload
echo "├░┼©ÔÇÿÔÇ░ Abilito e avvio il nuovo socket..."systemctl enable --now check-mk-agent-plain.socket
echo "├ó┼ôÔÇª Host configurato. Test locale:"/usr/bin/check_mk_agent | head -n 5EOF
# Loop sugli hostfor h in "${HOSTS[@]}"; do  
echo "============================"  
echo "├ó┼¥┬í├»┬©┬Å  Configuro $h"  
echo "============================"  ssh -o BatchMode=yes -o ConnectTimeout=10 ${USER}@${h} \    "
FORCE=${FORCE} bash -s" <<< "$REMOTE_SCRIPT"  
echo ""done

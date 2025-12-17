#!/bin/bash
# ==================================================
# Installazione e configurazione FRPC client (0.64.0)
# Riconosce automaticamente RockyLinux, NethServer,
# Debian e Proxmox VE
# ==================================================
FRP_VERSION="0.64.0"
FRP_URL_DEFAULT="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz"
echo "=== Installazione FRPC Client ==="
# ----------------------------
# 1. Rileva sistema operativo
# ----------------------------if grep -qi "rocky" /etc/os-release; then    
OS_TYPE="rockylinux"
elif grep -qi "nethserver" /etc/os-release; then    
OS_TYPE="nethserver"
elif grep -qi "debian" /etc/os-release; then    if dpkg -l | grep -q pve-manager; then        
OS_TYPE="proxmox"    else        
OS_TYPE="debian"    fi
else    
OS_TYPE="altro"
fi echo "Rilevato sistema operativo: $OS_TYPE"
# ----------------------------
# 2. Parametri richiesti
# ----------------------------read -r -p "URL pacchetto FRP [default: $FRP_URL_DEFAULT]: " 
FRP_URLFRP_URL=${FRP_URL:-$FRP_URL_DEFAULT}read -r -p "Nome host (es: rl94ns8): " HOSTNAMEread -r -p "Porta remota da usare: " REMOTE_PORT
# ----------------------------
# 3. Download e installazione
# ----------------------------cd /usr/local/src || exit 1wget -q "$FRP_URL" -O frp.tar.gztar xzf frp.tar.gzcd frp_${FRP_VERSION}_linux_amd64 || exit 1systemctl stop frpc 2>/dev/null || truecp frpc /usr/local/bin/frpcchmod +x /usr/local/bin/frpc
# ----------------------------
# 4. Configurazione TOML
# ----------------------------mkdir -p /etc/frpcat > /etc/frp/frpc.toml <<EOF[common]server_addr = "monitor.nethlab.it"server_port = 7000auth.method = "token"auth.token  = "conduit-reenact-talon-macarena-demotion-vaguely"tls.enable = truelog.to = "/var/log/frpc.log"log.level = "info"[$HOSTNAME]type        = "tcp"local_ip    = "127.0.0.1"local_port  = 6556remote_port = $REMOTE_PORTEOF
# ----------------------------
# 5. Configura servizio
# ----------------------------if [ "$OS_TYPE" = "rockylinux" ] || [ "$OS_TYPE" = "debian" ] || [ "$OS_TYPE" = "proxmox" ]; then    
echo "--- Configurazione systemd ($OS_TYPE) ---"    cat > /etc/systemd/system/frpc.service <<EOF[Unit]Description=FRP Client Service ($OS_TYPE)After=network.target[Service]Type=simpleExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.tomlRestart=on-failureRestartSec=5sUser=root[Install]WantedBy=multi-user.targetEOF    systemctl daemon-reload    systemctl enable frpc    systemctl restart frpc
elif [ "$OS_TYPE" = "nethserver" ]; then    
echo "--- Configurazione systemd via e-smith (NethServer) ---"    config set frpc service status enabled    mkdir -p /etc/e-smith/templates-custom/etc/systemd/system/frpc.service    cat > /etc/e-smith/templates-custom/etc/systemd/system/frpc.service/10base <<EOF[Unit]Description=FRP Client Service (NethServer)After=network.target[Service]Type=simpleExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.tomlRestart=on-failureRestartSec=5sUser=root[Install]WantedBy=multi-user.targetEOF    signal-event runlevel-adjust    systemctl enable frpc    systemctl restart frpc
else    
echo "├ó┼í┬á├»┬©┬Å  Sistema operativo non riconosciuto: configurazione manuale necessaria"
fi # ----------------------------
# 6. Verifica finale
# ----------------------------
echo "=== Installazione completata su $OS_TYPE ==="systemctl status frpc -l --no-pager

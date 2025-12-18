#!/usr/bin/env bash
set -euo pipefail

# Installazione interattiva CheckMK Agent (plain TCP 6556) + FRPC (opzionale)
# Output volutamente ASCII-only (niente cornici/emoji).

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CHECKMK_VERSION_DEFAULT="2.4.0p12"
FRP_VERSION="0.64.0"

MODE="install"
PKG_TYPE=""
PKG_MANAGER=""
OS_ID=""
OS_VER=""
CHECKMK_VERSION="$CHECKMK_VERSION_DEFAULT"

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }

log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }

log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

log_err() { echo -e "${RED}[ERR]${NC} $*"; }

die() { log_err "$*"; exit 1; }

require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        die "Questo script deve essere eseguito come root"
    fi
}

install_checkmk_agent() {
    if [[ "$PKG_TYPE" == "openwrt" ]]; then
        install_checkmk_agent_openwrt
    else
        install_checkmk_agent_linux
    fi
}

configure_plain_agent_openwrt() {
    need_cmd socat

    cat >/etc/init.d/check_mk_agent <<'EOF'
#!/bin/sh /etc/rc.common
START=98
STOP=10
USE_PROCD=1
PROG=/usr/bin/check_mk_agent

start_service() {
    mkdir -p /var/run
    procd_open_instance
    procd_set_param command socat TCP-LISTEN:6556,reuseaddr,fork,keepalive EXEC:$PROG
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    killall socat >/dev/null 2>&1 || true
}
EOF

    chmod +x /etc/init.d/check_mk_agent
    /etc/init.d/check_mk_agent enable >/dev/null 2>&1 || true
    /etc/init.d/check_mk_agent restart

    if pgrep -f "socat TCP-LISTEN:6556" >/dev/null 2>&1; then
        log_ok "Agent plain attivo su porta 6556 (OpenWrt: socat)"
    else
        log_warn "Listener socat non rilevato (verifica manualmente)"
    fi
}

configure_plain_agent_systemd() {
    # Prova a spegnere eventuali socket TLS/standard
    systemctl stop check-mk-agent.socket check-mk-agent@.service cmk-agent-ctl-daemon.service 2>/dev/null || true
    systemctl disable check-mk-agent.socket 2>/dev/null || true
    systemctl disable cmk-agent-ctl-daemon.service 2>/dev/null || true

    cat >/etc/systemd/system/check-mk-agent-plain.socket <<'EOF'
[Unit]
Description=Checkmk Agent (TCP 6556 plain)
Documentation=https://docs.checkmk.com/

[Socket]
ListenStream=6556
Accept=yes

[Install]
WantedBy=sockets.target
EOF

    cat >/etc/systemd/system/check-mk-agent-plain@.service <<'EOF'
[Unit]
Description=Checkmk Agent (TCP 6556 plain) connection

[Service]
ExecStart=-/usr/bin/check_mk_agent
StandardInput=socket
EOF

    systemctl daemon-reload
    systemctl enable --now check-mk-agent-plain.socket
    log_ok "Socket systemd attivo: check-mk-agent-plain.socket"
}

configure_plain_agent() {
    if [[ "$PKG_TYPE" == "openwrt" ]]; then
        configure_plain_agent_openwrt
    else
        configure_plain_agent_systemd
    fi
}

install_frpc() {
    local arch="amd64"
    case "$(uname -m)" in
        x86_64) arch="amd64";;
        aarch64|arm64) arch="arm64";;
    esac

    local url="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${arch}.tar.gz"
    local tmpdir
    tmpdir=$(mktemp -d)

    log_info "Download FRPC: $url"
    if command -v curl >/dev/null 2>&1; then
        curl -fL "$url" -o "$tmpdir/frp.tgz"
    else
        need_cmd wget
        wget -O "$tmpdir/frp.tgz" "$url"
    fi

    tar -xzf "$tmpdir/frp.tgz" -C "$tmpdir"
    local bin
    bin=$(find "$tmpdir" -type f -name frpc -print -quit)
    [[ -n "$bin" ]] || die "frpc non trovato nell'archivio"
    install -m 0755 "$bin" /usr/local/bin/frpc
    rm -rf "$tmpdir"

    log_ok "FRPC installato in /usr/local/bin/frpc"
}

configure_frpc() {
    local current_hostname
    current_hostname=$(hostname 2>/dev/null || echo "host")

    echo
    log_info "Configurazione FRPC"
    read -r -p "Nome host [default: $current_hostname]: " FRPC_HOSTNAME
    FRPC_HOSTNAME=${FRPC_HOSTNAME:-$current_hostname}

    read -r -p "Server FRP remoto [default: monitor.nethlab.it]: " FRP_SERVER
    FRP_SERVER=${FRP_SERVER:-monitor.nethlab.it}

    while true; do
        read -r -p "Porta remota (es: 20001): " REMOTE_PORT
        [[ "$REMOTE_PORT" =~ ^[0-9]+$ ]] && break
        log_err "Porta remota obbligatoria (numero)"
    done

    read -r -p "Token [default: conduit-reenact-talon-macarena-demotion-vaguely]: " AUTH_TOKEN
    AUTH_TOKEN=${AUTH_TOKEN:-conduit-reenact-talon-macarena-demotion-vaguely}

    mkdir -p /etc/frp
    cat >/etc/frp/frpc.toml <<EOF
[common]
server_addr = "$FRP_SERVER"
server_port = 7000
auth.method = "token"
auth.token  = "$AUTH_TOKEN"
tls.enable  = true
log.to      = "/var/log/frpc.log"
log.level   = "debug"

[$FRPC_HOSTNAME]
type        = "tcp"
local_ip    = "127.0.0.1"
local_port  = 6556
remote_port = $REMOTE_PORT
EOF

    if [[ "$PKG_TYPE" == "openwrt" ]]; then
        cat >/etc/init.d/frpc <<'EOF'
#!/bin/sh /etc/rc.common
START=99
STOP=10
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/local/bin/frpc -c /etc/frp/frpc.toml
    procd_set_param respawn
    procd_close_instance
}

stop_service() {
    killall frpc >/dev/null 2>&1 || true
}
EOF
        chmod +x /etc/init.d/frpc
        /etc/init.d/frpc enable >/dev/null 2>&1 || true
        /etc/init.d/frpc restart
    else
        cat >/etc/systemd/system/frpc.service <<'EOF'
[Unit]
Description=FRP Client Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.toml
Restart=on-failure
RestartSec=5s
User=root

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable --now frpc
    fi

    log_ok "FRPC configurato: $FRP_SERVER:$REMOTE_PORT -> localhost:6556"
}

uninstall_frpc() {
    log_info "Disinstallazione FRPC"
    killall frpc 2>/dev/null || true
    if [[ "$PKG_TYPE" == "openwrt" ]]; then
        /etc/init.d/frpc stop 2>/dev/null || true
        /etc/init.d/frpc disable 2>/dev/null || true
        rm -f /etc/init.d/frpc
    else
        systemctl stop frpc 2>/dev/null || true
        systemctl disable frpc 2>/dev/null || true
        rm -f /etc/systemd/system/frpc.service
        systemctl daemon-reload 2>/dev/null || true
    fi
    rm -f /usr/local/bin/frpc
    rm -rf /etc/frp
    rm -f /var/log/frpc.log
    log_ok "FRPC rimosso"
}

uninstall_agent() {
    log_info "Disinstallazione CheckMK Agent"
    killall check_mk_agent 2>/dev/null || true
    killall socat 2>/dev/null || true

    if [[ "$PKG_TYPE" == "openwrt" ]]; then
        /etc/init.d/check_mk_agent stop 2>/dev/null || true
        /etc/init.d/check_mk_agent disable 2>/dev/null || true
        rm -f /etc/init.d/check_mk_agent
        rm -f /usr/bin/check_mk_agent
        rm -rf /etc/check_mk
        log_ok "Agent rimosso (OpenWrt)"
        return 0
    fi

    systemctl stop check-mk-agent-plain.socket 2>/dev/null || true
    systemctl disable check-mk-agent-plain.socket 2>/dev/null || true
    rm -f /etc/systemd/system/check-mk-agent-plain.socket /etc/systemd/system/check-mk-agent-plain@.service
    systemctl daemon-reload 2>/dev/null || true

    if [[ "$PKG_TYPE" == "deb" ]]; then
        dpkg -r check-mk-agent 2>/dev/null || true
    else
        rpm -e check-mk-agent 2>/dev/null || true
    fi

    rm -f /usr/bin/check_mk_agent
    rm -rf /etc/check_mk
    log_ok "Agent rimosso"
}

parse_args() {
    case "${1:-}" in
        --help|-h)
            MODE="help";;
        --uninstall-frpc)
            MODE="uninstall-frpc";;
        --uninstall-agent)
            MODE="uninstall-agent";;
        --uninstall)
            MODE="uninstall-all";;
        "")
            MODE="install";;
        *)
            MODE="help";;
    esac
}

main() {
    parse_args "${1:-}"
    if [[ "$MODE" == "help" ]]; then
        show_usage
        exit 0
    fi

    require_root
    detect_os

    if [[ "$MODE" == "uninstall-frpc" ]]; then
        uninstall_frpc
        exit 0
    elif [[ "$MODE" == "uninstall-agent" ]]; then
        uninstall_agent
        exit 0
    elif [[ "$MODE" == "uninstall-all" ]]; then
        echo
        read -r -p "Sei sicuro di voler rimuovere tutto (Agent + FRPC)? [s/N]: " CONFIRM
        if [[ "$CONFIRM" =~ ^[sS]$ ]]; then
            uninstall_frpc
            uninstall_agent
            log_ok "Disinstallazione completa terminata"
        else
            log_info "Operazione annullata"
        fi
        exit 0
    fi

    echo
    log_info "Questa installazione configurera':"
    echo "- CheckMK Agent plain TCP (porta 6556)"
    if [[ "$PKG_TYPE" == "openwrt" ]]; then
        echo "- Listener: socat (init.d/procd)"
    else
        echo "- Socket systemd: check-mk-agent-plain.socket"
    fi
    echo
    read -r -p "Procedi con l'installazione? [s/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
        log_info "Installazione annullata"
        exit 0
    fi

    install_checkmk_agent
    configure_plain_agent

    echo
    read -r -p "Vuoi installare anche FRPC? [s/N]: " INSTALL_FRPC
    if [[ "$INSTALL_FRPC" =~ ^[sS]$ ]]; then
        install_frpc
        configure_frpc
    fi

    echo
    log_ok "Installazione completata"
    echo "Comandi utili:"
    echo "- Test agent locale: /usr/bin/check_mk_agent"
    if [[ "$PKG_TYPE" == "openwrt" ]]; then
        echo "- Stato agent: /etc/init.d/check_mk_agent status"
        echo "- Stato frpc : /etc/init.d/frpc status"
    else
        echo "- Stato socket: systemctl status check-mk-agent-plain.socket"
        echo "- Stato frpc  : systemctl status frpc"
    fi
}

main "$@"
: <<'__LEGACY__'
    echo -e "${RED}OooOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOou${NC}"    
echo -e "${RED}Oo        DISINSTALLAZIONE COMPLETA (Agent + FRPC)          Oo${NC}"    
echo -e "${RED}OoUOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOo${NC}"    
echo ""    read -r -p "$(
echo -e ${YELLOW}Sei sicuro di voler rimuovere tutto? ${NC}[s/N]: )" CONFIRM    if [[ "$CONFIRM" =~ ^[sS]$ ]]; then        uninstall_frpc        
echo ""        uninstall_agent        
echo -e "\n${GREEN}Ae Disinstallazione completa terminata!${NC}\n"
else        
echo -e "${CYAN}Oi Operazione annullata${NC}"    fi    exit 0
fi # =====================================================
# Modalita installazione (resto dello script originale)
# =====================================================set -e
echo -e "${CYAN}OooOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOou${NC}"
echo -e "${CYAN}Oo  Installazione Interattiva CheckMK Agent + FRPC          Oo${NC}"
echo -e "${CYAN}Oo  Version: 1.1 - $(date +%Y-%m-%d)                                Oo${NC}"
echo -e "${CYAN}OoUOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOo${NC}"
# =====================================================
# Funzione: Rileva sistema operativo
# =====================================================detect_os() {    if [ -f /etc/os-release ]; then        . /etc/os-release        
OS=$ID        
VER=$VERSION_ID                
# Rileva NethServer Enterprise (basato su Rocky Linux)        if [ -f /etc/nethserver-release ]; then
    OS="nethserver-enterprise"            
VER=$(cat /etc/nethserver-release | grep -oP 'NethServer Enterprise \K[0-9.]+' || 
echo "8")        fi                
# Rileva NethServer 8 Core / OpenWrt        if [ -f /etc/openwrt_release ] || grep -qi "openwrt" /etc/os-release 2>/dev/null; then
    OS="openwrt"            
VER=$(grep DISTRIB_RELEASE /etc/openwrt_release 2>/dev/null | cut -d"'" -f2 || 
echo "23.05")        fi
elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')        
VER=$(lsb_release -sr)    else        
OS=$(uname -s)        
VER=$(uname -r)    fi        case $OS in        ubuntu|debian)            
PKG_TYPE="deb"            
PKG_MANAGER="apt"            ;;        centos|rhel|rocky|almalinux|nethserver-enterprise)            
PKG_TYPE="rpm"            
PKG_MANAGER="yum"            ;;        openwrt)            
PKG_TYPE="openwrt"            
PKG_MANAGER="opkg"            ;;        *)            
echo -e "${RED}Ou Sistema operativo non supportato: $OS${NC}"
    exit 1            ;;    esac        
echo -e "${GREEN}Oo Sistema rilevato: $OS $VER ($PKG_TYPE)${NC}"}
# =====================================================
# Funzione: Rileva ultima versione CheckMK Agent
# =====================================================detect_latest_agent_version() {    
echo -e "${CYAN}oi Rilevamento ultima versione CheckMK Agent...${NC}"        local 
BASE_URL="https://monitoring.nethlab.it/monitoring/check_mk/agents"        
# Prova a rilevare l'ultima versione disponibile    if [ "$PKG_TYPE" = "deb" ]; then        
# Cerca file DEB        
LATEST_AGENT=$(wget -qO- "$BASE_URL/" 2>/dev/null | grep -oP 'check-mk-agent_\K[0-9]+\.[0-9]+\.[0-9]+p[0-9]+' | sort -V | tail -n 1)        if [ -n "$LATEST_AGENT" ]; then
    CHECKMK_VERSION="$LATEST_AGENT"        fi
else        
# Cerca file RPM        
LATEST_AGENT=$(wget -qO- "$BASE_URL/" 2>/dev/null | grep -oP 'check-mk-agent-\K[0-9]+\.[0-9]+\.[0-9]+p[0-9]+' | sort -V | tail -n 1)        if [ -n "$LATEST_AGENT" ]; then
    CHECKMK_VERSION="$LATEST_AGENT"        fi    fi
echo -e "${GREEN}   Oo Versione rilevata: ${CHECKMK_VERSION}${NC}"}
# =====================================================
# Funzione: Installa CheckMK Agent su OpenWrt/NethSec8
# =====================================================install_checkmk_agent_openwrt() {    
echo -e "\n${BLUE}OoEOoEOoE INSTALLAZIONE CHECKMK AGENT (OpenWrt/NethSec8) OoEOoEOoE${NC}"        
# Rileva versione    detect_latest_agent_version        local 
DEB_URL="https://monitoring.nethlab.it/monitoring/check_mk/agents/check-mk-agent_${CHECKMK_VERSION}-1_all.deb"    local 
TMPDIR="/tmp/checkmk-deb"        
# Repository OpenWrt    
echo -e "${YELLOW}oa Configurazione repository OpenWrt...${NC}"    local 
CUSTOMFEEDS="/etc/opkg/customfeeds.conf"    local 
REPO_BASE="https://downloads.openwrt.org/releases/23.05.0/packages/x86_64/base"    local 
REPO_PACKAGES="https://downloads.openwrt.org/releases/23.05.0/packages/x86_64/packages"        mkdir -p "$(dirname "$CUSTOMFEEDS")"    touch "$CUSTOMFEEDS"        grep -q "$REPO_BASE" "$CUSTOMFEEDS" || 
echo "src/gz openwrt_base $REPO_BASE" >> "$CUSTOMFEEDS"    grep -q "$REPO_PACKAGES" "$CUSTOMFEEDS" || 
echo "src/gz openwrt_packages $REPO_PACKAGES" >> "$CUSTOMFEEDS"        
# Installa tool necessari    
echo -e "${YELLOW}oa Installazione tool base...${NC}"    opkg update    opkg install binutils tar gzip wget socat ca-certificates 2>/dev/null || opkg install busybox-full        if ! command -v ar >/dev/null; then
    echo -e "${RED}Ou Coman
do 'ar' mancante${NC}"
    exit 1    fi        
# Scarica e estrai DEB    
echo -e "${YELLOW}oa Download CheckMK Agent...${NC}"    mkdir -p "$TMPDIR"    cd "$TMPDIR"        
echo -e "${CYAN}   Downloading...${NC}"    if wget "$DEB_URL" -O check-mk-agent.deb 2>&1; then
    echo -e "${GREEN}   Oo Download completato${NC}"
else        
echo -e "${RED}Ou Errore download${NC}"
    exit 1    fi        
# Estrazione manuale DEB    
echo -e "${YELLOW}oa Estrazione pacchetto DEB...${NC}"    ar x check-mk-agent.deb    mkdir -p data    tar -xzf data.tar.gz -C data        
# Installazione    
echo -e "${YELLOW}oa Installazione agent...${NC}"    cp -f data/usr/bin/check_mk_agent /usr/bin/ 2>/dev/null || true    chmod +x /usr/bin/check_mk_agent    mkdir -p /etc/check_mk /etc/xinetd.d    cp -rf data/etc/check_mk/* /etc/check_mk/ 2>/dev/null || true        rm -rf "$TMPDIR"    
echo -e "${GREEN}Oo Agent CheckMK installato${NC}"        
# Crea servizio init.d con socat    
echo -e "${YELLOW}oo Creazione servizio init.d (socat listener)...${NC}"        cat > /etc/init.d/check_mk_agent <<'EOF'
#!/bin/sh /etc/rc.common
# Checkmk Agent listener for OpenWrt / NethSecurity
START=98
STOP=10
USE_PROCD=1
PROG=/usr/bin/check_mk_agentstart_service() {    mkdir -p /var/run    
echo "Starting Checkmk Agent on TCP port 6556..."    procd_open_instance    procd_set_param command socat TCP-LISTEN:6556,reuseaddr,fork,keepalive EXEC:$PROG    procd_set_param respawn    procd_set_param stdout 1    procd_set_param stderr 1    procd_close_instance}

stop_service() {    
echo "Stopping Checkmk Agent..."    killall socat >/dev/null 2>&1 || true}EOF        chmod +x /etc/init.d/check_mk_agent    /etc/init.d/check_mk_agent enable >/dev/null 2>&1 || true    /etc/init.d/check_mk_agent restart        sleep 2        if pgrep -f "socat TCP-LISTEN:6556" >/dev/null 2>&1; then
    echo -e "${GREEN}Oo Agent attivo su porta 6556 (socat mode)${NC}"
else        
echo -e "${YELLOW}OUa A  Agent potrebbe non essere attivo${NC}"    fi        
# Test locale    
echo -e "\n${CYAN}oe Test agent locale:${NC}"    /usr/bin/check_mk_agent | head -n 5 || 
echo -e "${YELLOW}OUa A  Test fallito${NC}"}
# =====================================================
# Funzione: Installa CheckMK Agent
# =====================================================install_checkmk_agent() {    
# Se  OpenWrt, usa funzione specifica    if [ "$PKG_TYPE" = "openwrt" ]; then        install_checkmk_agent_openwrt        return    fi
echo -e "\n${BLUE}OoEOoEOoE INSTALLAZIONE CHECKMK AGENT OoEOoEOoE${NC}"        
# Rileva automaticamente l'ultima versione disponibile    detect_latest_agent_version        
# URL pacchetti    if [ "$PKG_TYPE" = "deb" ]; then
    AGENT_URL="https://monitoring.nethlab.it/monitoring/check_mk/agents/check-mk-agent_${CHECKMK_VERSION}-1_all.deb"        
AGENT_FILE="check-mk-agent.deb"
else        
AGENT_URL="https://monitoring.nethlab.it/monitoring/check_mk/agents/check-mk-agent-${CHECKMK_VERSION}-1.noarch.rpm"        
AGENT_FILE="check-mk-agent.rpm"    fi
echo -e "${YELLOW}oa Download agent da: $AGENT_URL${NC}"        cd /tmp    rm -f "$AGENT_FILE" 2>/dev/null        
# Download con output visibile    
echo -e "${CYAN}   Downloading...${NC}"    if wget "$AGENT_URL" -O "$AGENT_FILE" 2>&1; then
    echo -e "${GREEN}   Oo Download completato${NC}"
else        
echo -e "${RED}Ou Errore durante il download${NC}"
    exit 1    fi        
# Verifica che il file sia vali
do    if [ ! -f "$AGENT_FILE" ] || [ ! -s "$AGENT_FILE" ]; then
    echo -e "${RED}Ou File scaricato non vali
do o vuoto${NC}"
    exit 1    fi        
# Verifica che sia un file RPM/DEB vali
do (solo se coman
do 'file' disponibile)    if command -v file >/dev/null 2>&1; then
        if [ "$PKG_TYPE" = "rpm" ]; then
            if ! file "$AGENT_FILE" | grep -q "RPM"; then
    echo -e "${RED}Ou File scaricato non  un pacchetto RPM vali
do${NC}"                
echo -e "${YELLOW}Contenuto del file:${NC}"                head -n 5 "$AGENT_FILE"
    exit 1            fi
else            if ! file "$AGENT_FILE" | grep -q "Debian"; then
    echo -e "${RED}Ou File scaricato non  un pacchetto DEB vali
do${NC}"                
echo -e "${YELLOW}Contenuto del file:${NC}"                head -n 5 "$AGENT_FILE"
    exit 1            fi        fi    fi
echo -e "${YELLOW}oa Installazione pacchetto...${NC}"    if [ "$PKG_TYPE" = "deb" ]; then        dpkg -i "$AGENT_FILE"        apt-get install -f -y 2>/dev/null || true
else        rpm -Uvh "$AGENT_FILE"    fi        rm -f "$AGENT_FILE"    
echo -e "${GREEN}Oo Agent CheckMK installato${NC}"}
# =====================================================
# Funzione: Configura Agent Plain (TCP 6556)
# =====================================================configure_plain_agent() {    
# Su OpenWrt il servizio  gia configurato da install_checkmk_agent_openwrt()    if [ "$PKG_TYPE" = "openwrt" ]; then
    echo -e "${GREEN}Oo Agent su OpenWrt gia configurato${NC}"        return    fi
echo -e "\n${BLUE}OoEOoEOoE CONFIGURAZIONE AGENT PLAIN OoEOoEOoE${NC}"        
SOCKET_FILE="/etc/systemd/system/check-mk-agent-plain.socket"    
SERVICE_FILE="/etc/systemd/system/check-mk-agent-plain@.service"        
echo -e "${YELLOW}oo Disabilito TLS e socket standard...${NC}"    systemctl stop cmk-agent-ctl-daemon 2>/dev/null || true    systemctl disable cmk-agent-ctl-daemon 2>/dev/null || true    systemctl stop check-mk-agent.socket 2>/dev/null || true    systemctl disable check-mk-agent.socket 2>/dev/null || true        
echo -e "${YELLOW}oo Creo unit systemd per agent plain...${NC}"        cat > "$SOCKET_FILE" <<'EOF'
[Unit]Description=Checkmk Agent (TCP 6556 plain)Documentation=https://docs.checkmk.com/latest/en/agent_linux.html[Socket]ListenStream=6556Accept=yes[Install]WantedBy=sockets.targetEOF        cat > "$SERVICE_FILE" <<'EOF'
[Unit]Description=Checkmk Agent (TCP 6556 plain) connectionDocumentation=https://docs.checkmk.com/latest/en/agent_linux.html[Service]ExecStart=-/usr/bin/check_mk_agentStandardInput=socketEOF        
echo -e "${YELLOW}oo Ricarico systemd e avvio socket...${NC}"    systemctl daemon-reload    systemctl enable --now check-mk-agent-plain.socket        
echo -e "${GREEN}Oo Agent plain configurato su porta 6556${NC}"        
# Test locale    
echo -e "\n${CYAN}oe Test agent locale:${NC}"    /usr/bin/check_mk_agent | head -n 5}
# =====================================================
# Funzione: Installa FRPC
# =====================================================install_frpc() {    
echo -e "\n${BLUE}OoEOoEOoE INSTALLAZIONE FRPC CLIENT OoEOoEOoE${NC}"        
echo -e "${YELLOW}oa Download FRPC v${FRP_VERSION}...${NC}"        
# Per OpenWrt usa /tmp, per Linux usa /usr/local/src    local 
FRP_DIR="/tmp"    if [ "$PKG_TYPE" != "openwrt" ] && [ -d /usr/local/src ]; then
    FRP_DIR="/usr/local/src"    fi        cd "$FRP_DIR" || exit 1    rm -f "frp_${FRP_VERSION}_linux_amd64.tar.gz" 2>/dev/null        
# Download    
echo -e "${CYAN}   Downloading from GitHub...${NC}"    if wget "$FRP_URL" -O "frp_${FRP_VERSION}_linux_amd64.tar.gz" 2>&1; then
    echo -e "${GREEN}   Oo Download completato${NC}"
else        
echo -e "${RED}Ou Errore durante il download di FRPC${NC}"
    exit 1    fi        
# Verifica file    if [ ! -f "frp_${FRP_VERSION}_linux_amd64.tar.gz" ] || [ ! -s "frp_${FRP_VERSION}_linux_amd64.tar.gz" ]; then
    echo -e "${RED}Ou File FRPC non vali
do o vuoto${NC}"
    exit 1    fi
echo -e "${YELLOW}oa Estrazione...${NC}"    tar -xzf "frp_${FRP_VERSION}_linux_amd64.tar.gz"    
FRP_EXTRACTED=$(tar -tzf "frp_${FRP_VERSION}_linux_amd64.tar.gz" | head -1 | cut -f1 -d"/")        mkdir -p /usr/local/bin    cp -f "$FRP_EXTRACTED/frpc" /usr/local/bin/frpc    chmod +x /usr/local/bin/frpc        rm -rf "$FRP_EXTRACTED" "frp_${FRP_VERSION}_linux_amd64.tar.gz"        
echo -e "${GREEN}Oo FRPC installato in /usr/local/bin/frpc${NC}"}
# =====================================================
# Funzione: Configura FRPC
# =====================================================configure_frpc() {    
echo -e "\n${BLUE}OoEOoEOoE CONFIGURAZIONE FRPC OoEOoEOoE${NC}"        
# Hostname corrente come default (con fallback per OpenWrt)    
CURRENT_HOSTNAME=$(hostname 2>/dev/null || 
echo "openwrt-host")        
echo -e "${YELLOW}Inserisci le informazioni per la configurazione FRPC:${NC}\n"        
# Nome host    read -r -p "$(
echo -e ${CYAN}Nome host ${NC}[default: $CURRENT_HOSTNAME]: )" FRPC_HOSTNAME    
FRPC_HOSTNAME=${FRPC_HOSTNAME:-$CURRENT_HOSTNAME}        
# Server remoto    read -r -p "$(
echo -e ${CYAN}Server FRP remoto ${NC}[default: monitor.nethlab.it]: )" FRP_SERVER    
FRP_SERVER=${FRP_SERVER:-"monitor.nethlab.it"}        
# Porta remota    read -r -p "$(
echo -e ${CYAN}Porta remota ${NC}[es: 20001]: )" REMOTE_PORT    while [ -z "$REMOTE_PORT" ]; do        
echo -e "${RED}Ou Porta remota obbligatoria!${NC}"        read -r -p "$(
echo -e ${CYAN}Porta remota: ${NC})" REMOTE_PORT    done        
# Token di sicurezza    read -r -p "$(
echo -e ${CYAN}Token di sicurezza ${NC}[default: conduit-reenact-talon-macarena-demotion-vaguely]: )" AUTH_TOKEN    
AUTH_TOKEN=${AUTH_TOKEN:-"conduit-reenact-talon-macarena-demotion-vaguely"}        
# Crea directory config    mkdir -p /etc/frp        
# Genera configurazione TOML    
echo -e "\n${YELLOW}o Creazione file /etc/frp/frpc.toml...${NC}"        cat > /etc/frp/frpc.toml <<EOF
# Configurazione FRPC Client
# Generato il $(date)[common]server_addr = "$FRP_SERVER"server_port = 7000auth.method = "token"auth.token  = "$AUTH_TOKEN"tls.enable = truelog.to = "/var/log/frpc.log"log.level = "debug"[$FRPC_HOSTNAME]type        = "tcp"local_ip    = "127.0.0.1"local_port  = 6556remote_port = $REMOTE_PORTEOF        
echo -e "${GREEN}Oo File di configurazione creato${NC}"        
# Mostra configurazione    
echo -e "\n${CYAN}oi Configurazione FRPC:${NC}"    
echo -e "   Server:      ${GREEN}$FRP_SERVER:7000${NC}"    
echo -e "   Tunnel:      ${GREEN}$FRPC_HOSTNAME${NC}"    
echo -e "   Porta remota: ${GREEN}$REMOTE_PORT${NC}"    
echo -e "   Porta locale: ${GREEN}6556${NC}"        
# Crea servizio (systemd o init.d)    if [ "$PKG_TYPE" = "openwrt" ]; then        
# Init.d per OpenWrt        
echo -e "\n${YELLOW}oo Creazione servizio init.d...${NC}"                cat > /etc/init.d/frpc <<'EOF'
#!/bin/sh /etc/rc.common
START=99
STOP=10
USE_PROCD=1start_service() {    procd_open_instance    procd_set_param command /usr/local/bin/frpc -c /etc/frp/frpc.toml    procd_set_param respawn    procd_close_instance}

stop_service() {    killall frpc >/dev/null 2>&1 || true}EOF                chmod +x /etc/init.d/frpc        /etc/init.d/frpc enable >/dev/null 2>&1 || true        /etc/init.d/frpc start
else        
# Systemd per Linux standard        
echo -e "\n${YELLOW}oo Creazione servizio systemd...${NC}"                cat > /etc/systemd/system/frpc.service <<EOF
[Unit]Description=FRP Client ServiceAfter=network.targetWants=network-online.target[Service]Type=simpleExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.tomlRestart=on-failureRestartSec=5sUser=rootStandardOutput=journalStandardError=journal[Install]WantedBy=multi-user.targetEOF                systemctl daemon-reload        systemctl enable frpc        systemctl restart frpc    fi        sleep 2        
# Verifica stato    if [ "$PKG_TYPE" = "openwrt" ]; then
        if pgrep -f frpc >/dev/null 2>&1; then
    echo -e "${GREEN}Oo FRPC avviato con successo${NC}"
else            
echo -e "${RED}Ou Errore nell'avvio di FRPC${NC}"            
echo -e "${YELLOW}Verifica log: tail -f /var/log/frpc.log${NC}"        fi
elif systemctl is-active --quiet frpc; then
    echo -e "${GREEN}Oo FRPC avviato con successo${NC}"        
echo -e "\n${CYAN}oe Status:${NC}"        systemctl status frpc --no-pager -l | head -n 10    else        
echo -e "${RED}Ou Errore nell'avvio di FRPC${NC}"        
echo -e "${YELLOW}Log:${NC}"        journalctl -u frpc -n 20 --no-pager    fi}
# =====================================================
# Funzione: Riepilogo finale
# =====================================================show_summary() {    
echo -e "\n${GREEN}OooOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOou${NC}"    
echo -e "${GREEN}Oo              INSTALLAZIONE COMPLETATA                     Oo${NC}"    
echo -e "${GREEN}OoUOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOo${NC}"        
echo -e "\n${CYAN}oi RIEPILOGO:${NC}"    
echo -e "   Oo CheckMK Agent installato (plain TCP 6556)"    
echo -e "   Oo Socket systemd attivo: check-mk-agent-plain.socket"        if [ "$INSTALL_FRPC" = "yes" ]; then
    echo -e "   Oo FRPC Client installato e configurato"        
echo -e "   Oo Tunnel attivo: $FRP_SERVER:$REMOTE_PORT Oa localhost:6556"    fi
echo -e "\n${CYAN}oo COMANDI UTILI:${NC}"    
echo -e "   Test agent locale:    ${YELLOW}/usr/bin/check_mk_agent${NC}"    
echo -e "   Status socket:        ${YELLOW}systemctl status check-mk-agent-plain.socket${NC}"        if [ "$INSTALL_FRPC" = "yes" ]; then
    echo -e "   Status FRPC:          ${YELLOW}systemctl status frpc${NC}"        
echo -e "   Log FRPC:             ${YELLOW}journalctl -u frpc -f${NC}"        
echo -e "   Config FRPC:          ${YELLOW}/etc/frp/frpc.toml${NC}"    fi
echo -e "\n${GREEN}Ae Installazione terminata con successo!${NC}\n"}
# =====================================================
# MAIN SCRIPT
# =====================================================
# Verifica permessi root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Ou Questo script deve essere eseguito come root${NC}"
    exit 1
fi # Rileva sistema operativodetect_os
# =====================================================
# CONFERMA INIZIALE - Mostra SO rilevato
# =====================================================
echo -e "\n${CYAN}OooOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOou${NC}"
echo -e "${CYAN}Oo             RILEVAMENTO SISTEMA OPERATIVO                 Oo${NC}"
echo -e "${CYAN}OoUOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOo${NC}"
echo -e "\n${YELLOW}Sistema Rilevato:${NC}"
echo -e "   ${GREEN}OS:${NC} $OS"
echo -e "   ${GREEN}Versione:${NC} $VER"
echo -e "   ${GREEN}Package Manager:${NC} $PKG_TYPE"
# Mapping descrittivo del sistemacase "$OS" in    openwrt)        
SYSTEM_DESC="OpenWrt / NethSecurity (init.d + procd)"        ;;    ubuntu|debian)        
SYSTEM_DESC="Debian/Ubuntu (systemd)"        ;;    fedora|rocky|centos|rhel)        
SYSTEM_DESC="RHEL-based: $OS (systemd)"        ;;    nethserver-enterprise)        
SYSTEM_DESC="NethServer Enterprise (systemd)"        ;;    *)        
SYSTEM_DESC="$OS"        ;;esac
echo -e "   ${GREEN}Tipo:${NC} $SYSTEM_DESC"
echo -e "\n${YELLOW}Questa installazione utilizzera:${NC}"
echo -e "   OCo CheckMK Agent (plain TCP on port 6556)"
echo -e "   OCo Servizio: $([ "$PKG_TYPE" = "openwrt" ] && 
echo "init.d" || 
echo "systemd socket")"if [ "$PKG_TYPE" = "openwrt" ]; then
    echo -e "   OCo TCP Listener: socat"
fi
echo -e "\n${YELLOW}OoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoE${NC}"read -r -p "$(
echo -e ${CYAN}Procedi con l\"installazione su questo sistema? ${NC}[s/N]: )" CONFIRM_SYSTEM
echo -e "${YELLOW}OoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoE${NC}"if [[ ! "$CONFIRM_SYSTEM" =~ ^[sS]$ ]]; then
    echo -e "\n${CYAN}Installazione annullata dall\"utente${NC}\n"
    exit 0
fi echo -e "\n${GREEN}Proceden
do con l\"installazione...${NC}\n"
# Installa CheckMK Agentinstall_checkmk_agent
# Configura agent plainconfigure_plain_agent
# Chiedi se installare FRPC
echo -e "\n${YELLOW}OoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoE${NC}"read -r -p "$(
echo -e ${CYAN}Vuoi installare anche FRPC? ${NC}[s/N]: )" INSTALL_FRPC_INPUT
echo -e "${YELLOW}OoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoEOoE${NC}"
INSTALL_FRPC="no"
if [[ "$INSTALL_FRPC_INPUT" =~ ^[sS]$ ]]; then
    INSTALL_FRPC="yes"    install_frpc    configure_frpc
else    
echo -e "${YELLOW}OA A  Installazione FRPC saltata${NC}"fi
# Mostra riepilogo finaleshow_summaryexit 0
__LEGACY__

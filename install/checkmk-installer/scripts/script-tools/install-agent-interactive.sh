#!/bin/bash
# =====================================================
# Script Interattivo: Installazione CheckMK Agent + FRPC (opzionale)
# - Installa agent CheckMK in modalit├á plain (TCP 6556)
# - Opzionalmente installa e configura FRPC client
# - Configurazione guidata interattiva
# - Supporto disinstallazione completa
# =====================================================
# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' 
# No Color
# Variabili globali
CHECKMK_VERSION="2.4.0p12"
FRP_VERSION="0.64.0"
FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz"
# Modalit├á operativa
MODE="install"
# =====================================================
# Funzione: Mostra uso
# =====================================================show_usage() {    
echo -e "${CYAN}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"    
echo -e "${CYAN}Ôòæ  Installazione Interattiva CheckMK Agent + FRPC          Ôòæ${NC}"    
echo -e "${CYAN}Ôòæ  Version: 1.1 - $(date +%Y-%m-%d)                                Ôòæ${NC}"    
echo -e "${CYAN}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"    
echo ""    
echo -e "${YELLOW}Uso:${NC}"    
echo -e "  $0                      ${GREEN}
# Installazione interattiva${NC}"    
echo -e "  $0 --uninstall-frpc     ${RED}
# Rimuove solo FRPC${NC}"    
echo -e "  $0 --uninstall-agent    ${RED}
# Rimuove solo CheckMK Agent${NC}"    
echo -e "  $0 --uninstall          ${RED}
# Rimuove tutto (FRPC + Agent)${NC}"    
echo -e "  $0 --help               ${CYAN}
# Mostra questo messaggio${NC}"    
echo ""
    exit 0}
# =====================================================
# Funzione: Disinstalla FRPC
# =====================================================uninstall_frpc() {    
echo -e "\n${RED}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"    
echo -e "${RED}Ôòæ           DISINSTALLAZIONE FRPC CLIENT                    Ôòæ${NC}"    
echo -e "${RED}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"        
echo -e "\n${YELLOW}­ƒùæ´©Å  Rimozione FRPC in corso...${NC}\n"        
# Kill processi FRPC    killall frpc 2>/dev/null || true        
# Gestisci servizi per il tipo di sistema    if [ "$PKG_TYPE" = "openwrt" ]; then        
# OpenWrt: init.d        if [ -f /etc/init.d/frpc ]; then
    echo -e "${YELLOW}ÔÅ╣´©Å  Arresto servizio FRPC...${NC}"            /etc/init.d/frpc stop 2>/dev/null || true            /etc/init.d/frpc disable 2>/dev/null || true            rm -f /etc/init.d/frpc        fi    else        
# Linux: systemd        if systemctl is-active --quiet frpc 2>/dev/null; then
    echo -e "${YELLOW}ÔÅ╣´©Å  Arresto servizio FRPC...${NC}"            systemctl stop frpc 2>/dev/null || true        fi                if systemctl is-enabled --quiet frpc 2>/dev/null; then
    echo -e "${YELLOW}ÔÅ╣´©Å  Disabilito servizio FRPC...${NC}"            systemctl disable frpc 2>/dev/null || true        fi                if [ -f /etc/systemd/system/frpc.service ]; then
    echo -e "${YELLOW}­ƒùæ´©Å  Rimozione file systemd...${NC}"            rm -f /etc/systemd/system/frpc.service            systemctl daemon-reload 2>/dev/null || true        fi    fi        
# Rimuovi eseguibile    if [ -f /usr/local/bin/frpc ]; then
    echo -e "${YELLOW}­ƒùæ´©Å  Rimozione eseguibile...${NC}"        rm -f /usr/local/bin/frpc    fi        
# Rimuovi configurazione    if [ -d /etc/frp ]; then
    echo -e "${YELLOW}­ƒùæ´©Å  Rimozione directory configurazione...${NC}"        rm -rf /etc/frp    fi        
# Rimuovi log    if [ -f /var/log/frpc.log ]; then
    echo -e "${YELLOW}­ƒùæ´©Å  Rimozione file log...${NC}"        rm -f /var/log/frpc.log    fi
echo -e "\n${GREEN}Ô£à FRPC disinstallato completamente${NC}"    
echo -e "${CYAN}­ƒôï File rimossi:${NC}"    
echo -e "   ÔÇó /usr/local/bin/frpc"    
echo -e "   ÔÇó /etc/frp/"    
echo -e "   ÔÇó /etc/systemd/system/frpc.service (Linux)"    
echo -e "   ÔÇó /etc/init.d/frpc (OpenWrt)"    
echo -e "   ÔÇó /var/log/frpc.log"}
# =====================================================
# Funzione: Disinstalla CheckMK Agent
# =====================================================uninstall_agent() {    
echo -e "\n${RED}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"    
echo -e "${RED}Ôòæ        DISINSTALLAZIONE CHECKMK AGENT                     Ôòæ${NC}"    
echo -e "${RED}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"        
echo -e "\n${YELLOW}­ƒùæ´©Å  Rimozione CheckMK Agent in corso...${NC}\n"        
# Kill processi    killall check_mk_agent 2>/dev/null || true    killall socat 2>/dev/null || true        
# Gestisci servizi per il tipo di sistema    if [ "$PKG_TYPE" = "openwrt" ]; then        
# OpenWrt: init.d        if [ -f /etc/init.d/check_mk_agent ]; then
    echo -e "${YELLOW}ÔÅ╣´©Å  Arresto servizio agent...${NC}"            /etc/init.d/check_mk_agent stop 2>/dev/null || true            /etc/init.d/check_mk_agent disable 2>/dev/null || true            rm -f /etc/init.d/check_mk_agent        fi    else        
# Linux: systemd socket        if systemctl is-active --quiet check-mk-agent-plain.socket 2>/dev/null; then
    echo -e "${YELLOW}ÔÅ╣´©Å  Arresto socket plain...${NC}"            systemctl stop check-mk-agent-plain.socket 2>/dev/null || true        fi                if systemctl is-enabled --quiet check-mk-agent-plain.socket 2>/dev/null; then
    echo -e "${YELLOW}ÔÅ╣´©Å  Disabilito socket plain...${NC}"            systemctl disable check-mk-agent-plain.socket 2>/dev/null || true        fi                if [ -f /etc/systemd/system/check-mk-agent-plain.socket ]; then
    echo -e "${YELLOW}­ƒùæ´©Å  Rimozione socket systemd plain...${NC}"            rm -f /etc/systemd/system/check-mk-agent-plain.socket        fi                if [ -f /etc/systemd/system/check-mk-agent-plain@.service ]; then
    echo -e "${YELLOW}­ƒùæ´©Å  Rimozione service systemd plain...${NC}"            rm -f /etc/systemd/system/check-mk-agent-plain@.service        fi                systemctl daemon-reload 2>/dev/null || true    fi        
# Rimuovi eseguibile    if [ -f /usr/bin/check_mk_agent ]; then
    echo -e "${YELLOW}´┐¢´©Å  Rimozione eseguibile agent...${NC}"        rm -f /usr/bin/check_mk_agent    fi        
# Rimuovi configurazione    if [ -d /etc/check_mk ]; then
    echo -e "${YELLOW}­ƒùæ´©Å  Rimozione directory configurazione...${NC}"        rm -rf /etc/check_mk    fi        
# Rimuovi xinetd config (se presente)    if [ -f /etc/xinetd.d/check_mk ]; then
    echo -e "${YELLOW}­ƒùæ´©Å  Rimozione configurazione xinetd...${NC}"        rm -f /etc/xinetd.d/check_mk        systemctl reload xinetd 2>/dev/null || true    fi
echo -e "\n${GREEN}Ô£à CheckMK Agent disinstallato completamente${NC}"    
echo -e "${CYAN}­ƒôï File rimossi:${NC}"    
echo -e "   ÔÇó /usr/bin/check_mk_agent"    
echo -e "   ÔÇó /etc/check_mk/"    
echo -e "   ÔÇó /etc/init.d/check_mk_agent (OpenWrt)"    
echo -e "   ÔÇó /etc/systemd/system/check-mk-agent-plain.* (Linux)"}
# =====================================================
# Gestione parametri
# =====================================================case "$1" in    --help|-h)        show_usage        ;;    --uninstall-frpc)        
MODE="uninstall-frpc"        ;;    --uninstall-agent)        
MODE="uninstall-agent"        ;;    --uninstall)        
MODE="uninstall-all"        ;;    "")        
MODE="install"        ;;    *)        
echo -e "${RED}Ô£ù Parametro non vali
do: $1${NC}"        show_usage        ;;esac
# Verifica permessi root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Ô£ù Questo script deve essere eseguito come root${NC}"
    exit 1
fi # =====================================================
# Esegui modalit├á richiesta
# =====================================================if [ "$MODE" = "uninstall-frpc" ]; then    uninstall_frpc    exit 0
elif [ "$MODE" = "uninstall-agent" ]; then    uninstall_agent    exit 0
elif [ "$MODE" = "uninstall-all" ]; then
    echo -e "${RED}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"    
echo -e "${RED}Ôòæ        DISINSTALLAZIONE COMPLETA (Agent + FRPC)          Ôòæ${NC}"    
echo -e "${RED}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"    
echo ""    read -r -p "$(
echo -e ${YELLOW}Sei sicuro di voler rimuovere tutto? ${NC}[s/N]: )" CONFIRM    if [[ "$CONFIRM" =~ ^[sS]$ ]]; then        uninstall_frpc        
echo ""        uninstall_agent        
echo -e "\n${GREEN}­ƒÄë Disinstallazione completa terminata!${NC}\n"    else        
echo -e "${CYAN}ÔØî Operazione annullata${NC}"    fi    exit 0
fi # =====================================================
# Modalit├á installazione (resto dello script originale)
# =====================================================set -e
echo -e "${CYAN}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"
echo -e "${CYAN}Ôòæ  Installazione Interattiva CheckMK Agent + FRPC          Ôòæ${NC}"
echo -e "${CYAN}Ôòæ  Version: 1.1 - $(date +%Y-%m-%d)                                Ôòæ${NC}"
echo -e "${CYAN}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"
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
echo "23.05")        fi    elif type lsb_release >/dev/null 2>&1; then
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
echo -e "${RED}Ô£ù Sistema operativo non supportato: $OS${NC}"
    exit 1            ;;    esac        
echo -e "${GREEN}Ô£ô Sistema rilevato: $OS $VER ($PKG_TYPE)${NC}"}
# =====================================================
# Funzione: Rileva ultima versione CheckMK Agent
# =====================================================detect_latest_agent_version() {    
echo -e "${CYAN}­ƒöì Rilevamento ultima versione CheckMK Agent...${NC}"        local 
BASE_URL="https://monitoring.nethlab.it/monitoring/check_mk/agents"        
# Prova a rilevare l'ultima versione disponibile    if [ "$PKG_TYPE" = "deb" ]; then        
# Cerca file DEB        
LATEST_AGENT=$(wget -qO- "$BASE_URL/" 2>/dev/null | grep -oP 'check-mk-agent_\K[0-9]+\.[0-9]+\.[0-9]+p[0-9]+' | sort -V | tail -n 1)        if [ -n "$LATEST_AGENT" ]; then
    CHECKMK_VERSION="$LATEST_AGENT"        fi    else        
# Cerca file RPM        
LATEST_AGENT=$(wget -qO- "$BASE_URL/" 2>/dev/null | grep -oP 'check-mk-agent-\K[0-9]+\.[0-9]+\.[0-9]+p[0-9]+' | sort -V | tail -n 1)        if [ -n "$LATEST_AGENT" ]; then
    CHECKMK_VERSION="$LATEST_AGENT"        fi    fi
echo -e "${GREEN}   Ô£ô Versione rilevata: ${CHECKMK_VERSION}${NC}"}
# =====================================================
# Funzione: Installa CheckMK Agent su OpenWrt/NethSec8
# =====================================================install_checkmk_agent_openwrt() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ INSTALLAZIONE CHECKMK AGENT (OpenWrt/NethSec8) ÔòÉÔòÉÔòÉ${NC}"        
# Rileva versione    detect_latest_agent_version        local 
DEB_URL="https://monitoring.nethlab.it/monitoring/check_mk/agents/check-mk-agent_${CHECKMK_VERSION}-1_all.deb"    local 
TMPDIR="/tmp/checkmk-deb"        
# Repository OpenWrt    
echo -e "${YELLOW}­ƒôª Configurazione repository OpenWrt...${NC}"    local 
CUSTOMFEEDS="/etc/opkg/customfeeds.conf"    local 
REPO_BASE="https://downloads.openwrt.org/releases/23.05.0/packages/x86_64/base"    local 
REPO_PACKAGES="https://downloads.openwrt.org/releases/23.05.0/packages/x86_64/packages"        mkdir -p "$(dirname "$CUSTOMFEEDS")"    touch "$CUSTOMFEEDS"        grep -q "$REPO_BASE" "$CUSTOMFEEDS" || 
echo "src/gz openwrt_base $REPO_BASE" >> "$CUSTOMFEEDS"    grep -q "$REPO_PACKAGES" "$CUSTOMFEEDS" || 
echo "src/gz openwrt_packages $REPO_PACKAGES" >> "$CUSTOMFEEDS"        
# Installa tool necessari    
echo -e "${YELLOW}­ƒôª Installazione tool base...${NC}"    opkg update    opkg install binutils tar gzip wget socat ca-certificates 2>/dev/null || opkg install busybox-full        if ! command -v ar >/dev/null; then
    echo -e "${RED}Ô£ù Coman
do 'ar' mancante${NC}"
    exit 1    fi        
# Scarica e estrai DEB    
echo -e "${YELLOW}­ƒôª Download CheckMK Agent...${NC}"    mkdir -p "$TMPDIR"    cd "$TMPDIR"        
echo -e "${CYAN}   Downloading...${NC}"    if wget "$DEB_URL" -O check-mk-agent.deb 2>&1; then
    echo -e "${GREEN}   Ô£ô Download completato${NC}"    else        
echo -e "${RED}Ô£ù Errore download${NC}"
    exit 1    fi        
# Estrazione manuale DEB    
echo -e "${YELLOW}­ƒôª Estrazione pacchetto DEB...${NC}"    ar x check-mk-agent.deb    mkdir -p data    tar -xzf data.tar.gz -C data        
# Installazione    
echo -e "${YELLOW}­ƒôª Installazione agent...${NC}"    cp -f data/usr/bin/check_mk_agent /usr/bin/ 2>/dev/null || true    chmod +x /usr/bin/check_mk_agent    mkdir -p /etc/check_mk /etc/xinetd.d    cp -rf data/etc/check_mk/* /etc/check_mk/ 2>/dev/null || true        rm -rf "$TMPDIR"    
echo -e "${GREEN}Ô£ô Agent CheckMK installato${NC}"        
# Crea servizio init.d con socat    
echo -e "${YELLOW}­ƒöº Creazione servizio init.d (socat listener)...${NC}"        cat > /etc/init.d/check_mk_agent <<'EOF'
#!/bin/sh /etc/rc.common
# Checkmk Agent listener for OpenWrt / NethSecurity
START=98
STOP=10
USE_PROCD=1
PROG=/usr/bin/check_mk_agentstart_service() {    mkdir -p /var/run    
echo "Starting Checkmk Agent on TCP port 6556..."    procd_open_instance    procd_set_param command socat TCP-LISTEN:6556,reuseaddr,fork,keepalive EXEC:$PROG    procd_set_param respawn    procd_set_param stdout 1    procd_set_param stderr 1    procd_close_instance}stop_service() {    
echo "Stopping Checkmk Agent..."    killall socat >/dev/null 2>&1 || true}EOF        chmod +x /etc/init.d/check_mk_agent    /etc/init.d/check_mk_agent enable >/dev/null 2>&1 || true    /etc/init.d/check_mk_agent restart        sleep 2        if pgrep -f "socat TCP-LISTEN:6556" >/dev/null 2>&1; then
    echo -e "${GREEN}Ô£ô Agent attivo su porta 6556 (socat mode)${NC}"    else        
echo -e "${YELLOW}ÔÜá´©Å  Agent potrebbe non essere attivo${NC}"    fi        
# Test locale    
echo -e "\n${CYAN}­ƒôè Test agent locale:${NC}"    /usr/bin/check_mk_agent | head -n 5 || 
echo -e "${YELLOW}ÔÜá´©Å  Test fallito${NC}"}
# =====================================================
# Funzione: Installa CheckMK Agent
# =====================================================install_checkmk_agent() {    
# Se ├¿ OpenWrt, usa funzione specifica    if [ "$PKG_TYPE" = "openwrt" ]; then        install_checkmk_agent_openwrt        return    fi
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ INSTALLAZIONE CHECKMK AGENT ÔòÉÔòÉÔòÉ${NC}"        
# Rileva automaticamente l'ultima versione disponibile    detect_latest_agent_version        
# URL pacchetti    if [ "$PKG_TYPE" = "deb" ]; then
    AGENT_URL="https://monitoring.nethlab.it/monitoring/check_mk/agents/check-mk-agent_${CHECKMK_VERSION}-1_all.deb"        
AGENT_FILE="check-mk-agent.deb"    else        
AGENT_URL="https://monitoring.nethlab.it/monitoring/check_mk/agents/check-mk-agent-${CHECKMK_VERSION}-1.noarch.rpm"        
AGENT_FILE="check-mk-agent.rpm"    fi
echo -e "${YELLOW}­ƒôª Download agent da: $AGENT_URL${NC}"        cd /tmp    rm -f "$AGENT_FILE" 2>/dev/null        
# Download con output visibile    
echo -e "${CYAN}   Downloading...${NC}"    if wget "$AGENT_URL" -O "$AGENT_FILE" 2>&1; then
    echo -e "${GREEN}   Ô£ô Download completato${NC}"    else        
echo -e "${RED}Ô£ù Errore durante il download${NC}"
    exit 1    fi        
# Verifica che il file sia vali
do    if [ ! -f "$AGENT_FILE" ] || [ ! -s "$AGENT_FILE" ]; then
    echo -e "${RED}Ô£ù File scaricato non vali
do o vuoto${NC}"
    exit 1    fi        
# Verifica che sia un file RPM/DEB vali
do (solo se coman
do 'file' disponibile)    if command -v file >/dev/null 2>&1; then        if [ "$PKG_TYPE" = "rpm" ]; then            if ! file "$AGENT_FILE" | grep -q "RPM"; then
    echo -e "${RED}Ô£ù File scaricato non ├¿ un pacchetto RPM vali
do${NC}"                
echo -e "${YELLOW}Contenuto del file:${NC}"                head -n 5 "$AGENT_FILE"
    exit 1            fi        else            if ! file "$AGENT_FILE" | grep -q "Debian"; then
    echo -e "${RED}Ô£ù File scaricato non ├¿ un pacchetto DEB vali
do${NC}"                
echo -e "${YELLOW}Contenuto del file:${NC}"                head -n 5 "$AGENT_FILE"
    exit 1            fi        fi    fi
echo -e "${YELLOW}­ƒôª Installazione pacchetto...${NC}"    if [ "$PKG_TYPE" = "deb" ]; then        dpkg -i "$AGENT_FILE"        apt-get install -f -y 2>/dev/null || true    else        rpm -Uvh "$AGENT_FILE"    fi        rm -f "$AGENT_FILE"    
echo -e "${GREEN}Ô£ô Agent CheckMK installato${NC}"}
# =====================================================
# Funzione: Configura Agent Plain (TCP 6556)
# =====================================================configure_plain_agent() {    
# Su OpenWrt il servizio ├¿ gi├á configurato da install_checkmk_agent_openwrt()    if [ "$PKG_TYPE" = "openwrt" ]; then
    echo -e "${GREEN}Ô£ô Agent su OpenWrt gi├á configurato${NC}"        return    fi
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ CONFIGURAZIONE AGENT PLAIN ÔòÉÔòÉÔòÉ${NC}"        
SOCKET_FILE="/etc/systemd/system/check-mk-agent-plain.socket"    
SERVICE_FILE="/etc/systemd/system/check-mk-agent-plain@.service"        
echo -e "${YELLOW}­ƒöº Disabilito TLS e socket standard...${NC}"    systemctl stop cmk-agent-ctl-daemon 2>/dev/null || true    systemctl disable cmk-agent-ctl-daemon 2>/dev/null || true    systemctl stop check-mk-agent.socket 2>/dev/null || true    systemctl disable check-mk-agent.socket 2>/dev/null || true        
echo -e "${YELLOW}­ƒöº Creo unit systemd per agent plain...${NC}"        cat > "$SOCKET_FILE" <<'EOF'[Unit]Description=Checkmk Agent (TCP 6556 plain)Documentation=https://docs.checkmk.com/latest/en/agent_linux.html[Socket]ListenStream=6556Accept=yes[Install]WantedBy=sockets.targetEOF        cat > "$SERVICE_FILE" <<'EOF'[Unit]Description=Checkmk Agent (TCP 6556 plain) connectionDocumentation=https://docs.checkmk.com/latest/en/agent_linux.html[Service]ExecStart=-/usr/bin/check_mk_agentStandardInput=socketEOF        
echo -e "${YELLOW}­ƒöº Ricarico systemd e avvio socket...${NC}"    systemctl daemon-reload    systemctl enable --now check-mk-agent-plain.socket        
echo -e "${GREEN}Ô£ô Agent plain configurato su porta 6556${NC}"        
# Test locale    
echo -e "\n${CYAN}­ƒôè Test agent locale:${NC}"    /usr/bin/check_mk_agent | head -n 5}
# =====================================================
# Funzione: Installa FRPC
# =====================================================install_frpc() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ INSTALLAZIONE FRPC CLIENT ÔòÉÔòÉÔòÉ${NC}"        
echo -e "${YELLOW}­ƒôª Download FRPC v${FRP_VERSION}...${NC}"        
# Per OpenWrt usa /tmp, per Linux usa /usr/local/src    local 
FRP_DIR="/tmp"    if [ "$PKG_TYPE" != "openwrt" ] && [ -d /usr/local/src ]; then
    FRP_DIR="/usr/local/src"    fi        cd "$FRP_DIR" || exit 1    rm -f "frp_${FRP_VERSION}_linux_amd64.tar.gz" 2>/dev/null        
# Download    
echo -e "${CYAN}   Downloading from GitHub...${NC}"    if wget "$FRP_URL" -O "frp_${FRP_VERSION}_linux_amd64.tar.gz" 2>&1; then
    echo -e "${GREEN}   Ô£ô Download completato${NC}"    else        
echo -e "${RED}Ô£ù Errore durante il download di FRPC${NC}"
    exit 1    fi        
# Verifica file    if [ ! -f "frp_${FRP_VERSION}_linux_amd64.tar.gz" ] || [ ! -s "frp_${FRP_VERSION}_linux_amd64.tar.gz" ]; then
    echo -e "${RED}Ô£ù File FRPC non vali
do o vuoto${NC}"
    exit 1    fi
echo -e "${YELLOW}­ƒôª Estrazione...${NC}"    tar -xzf "frp_${FRP_VERSION}_linux_amd64.tar.gz"    
FRP_EXTRACTED=$(tar -tzf "frp_${FRP_VERSION}_linux_amd64.tar.gz" | head -1 | cut -f1 -d"/")        mkdir -p /usr/local/bin    cp -f "$FRP_EXTRACTED/frpc" /usr/local/bin/frpc    chmod +x /usr/local/bin/frpc        rm -rf "$FRP_EXTRACTED" "frp_${FRP_VERSION}_linux_amd64.tar.gz"        
echo -e "${GREEN}Ô£ô FRPC installato in /usr/local/bin/frpc${NC}"}
# =====================================================
# Funzione: Configura FRPC
# =====================================================configure_frpc() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ CONFIGURAZIONE FRPC ÔòÉÔòÉÔòÉ${NC}"        
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
echo -e "${RED}Ô£ù Porta remota obbligatoria!${NC}"        read -r -p "$(
echo -e ${CYAN}Porta remota: ${NC})" REMOTE_PORT    done        
# Token di sicurezza    read -r -p "$(
echo -e ${CYAN}Token di sicurezza ${NC}[default: conduit-reenact-talon-macarena-demotion-vaguely]: )" AUTH_TOKEN    
AUTH_TOKEN=${AUTH_TOKEN:-"conduit-reenact-talon-macarena-demotion-vaguely"}        
# Crea directory config    mkdir -p /etc/frp        
# Genera configurazione TOML    
echo -e "\n${YELLOW}­ƒôØ Creazione file /etc/frp/frpc.toml...${NC}"        cat > /etc/frp/frpc.toml <<EOF
# Configurazione FRPC Client
# Generato il $(date)[common]server_addr = "$FRP_SERVER"server_port = 7000auth.method = "token"auth.token  = "$AUTH_TOKEN"tls.enable = truelog.to = "/var/log/frpc.log"log.level = "debug"[$FRPC_HOSTNAME]type        = "tcp"local_ip    = "127.0.0.1"local_port  = 6556remote_port = $REMOTE_PORTEOF        
echo -e "${GREEN}Ô£ô File di configurazione creato${NC}"        
# Mostra configurazione    
echo -e "\n${CYAN}­ƒôï Configurazione FRPC:${NC}"    
echo -e "   Server:      ${GREEN}$FRP_SERVER:7000${NC}"    
echo -e "   Tunnel:      ${GREEN}$FRPC_HOSTNAME${NC}"    
echo -e "   Porta remota: ${GREEN}$REMOTE_PORT${NC}"    
echo -e "   Porta locale: ${GREEN}6556${NC}"        
# Crea servizio (systemd o init.d)    if [ "$PKG_TYPE" = "openwrt" ]; then        
# Init.d per OpenWrt        
echo -e "\n${YELLOW}­ƒöº Creazione servizio init.d...${NC}"                cat > /etc/init.d/frpc <<'EOF'
#!/bin/sh /etc/rc.common
START=99
STOP=10
USE_PROCD=1start_service() {    procd_open_instance    procd_set_param command /usr/local/bin/frpc -c /etc/frp/frpc.toml    procd_set_param respawn    procd_close_instance}stop_service() {    killall frpc >/dev/null 2>&1 || true}EOF                chmod +x /etc/init.d/frpc        /etc/init.d/frpc enable >/dev/null 2>&1 || true        /etc/init.d/frpc start    else        
# Systemd per Linux standard        
echo -e "\n${YELLOW}­ƒöº Creazione servizio systemd...${NC}"                cat > /etc/systemd/system/frpc.service <<EOF[Unit]Description=FRP Client ServiceAfter=network.targetWants=network-online.target[Service]Type=simpleExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.tomlRestart=on-failureRestartSec=5sUser=rootStandardOutput=journalStandardError=journal[Install]WantedBy=multi-user.targetEOF                systemctl daemon-reload        systemctl enable frpc        systemctl restart frpc    fi        sleep 2        
# Verifica stato    if [ "$PKG_TYPE" = "openwrt" ]; then        if pgrep -f frpc >/dev/null 2>&1; then
    echo -e "${GREEN}Ô£ô FRPC avviato con successo${NC}"        else            
echo -e "${RED}Ô£ù Errore nell'avvio di FRPC${NC}"            
echo -e "${YELLOW}Verifica log: tail -f /var/log/frpc.log${NC}"        fi    elif systemctl is-active --quiet frpc; then
    echo -e "${GREEN}Ô£ô FRPC avviato con successo${NC}"        
echo -e "\n${CYAN}­ƒôè Status:${NC}"        systemctl status frpc --no-pager -l | head -n 10    else        
echo -e "${RED}Ô£ù Errore nell'avvio di FRPC${NC}"        
echo -e "${YELLOW}Log:${NC}"        journalctl -u frpc -n 20 --no-pager    fi}
# =====================================================
# Funzione: Riepilogo finale
# =====================================================show_summary() {    
echo -e "\n${GREEN}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"    
echo -e "${GREEN}Ôòæ              INSTALLAZIONE COMPLETATA                     Ôòæ${NC}"    
echo -e "${GREEN}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"        
echo -e "\n${CYAN}­ƒôï RIEPILOGO:${NC}"    
echo -e "   Ô£ô CheckMK Agent installato (plain TCP 6556)"    
echo -e "   Ô£ô Socket systemd attivo: check-mk-agent-plain.socket"        if [ "$INSTALL_FRPC" = "yes" ]; then
    echo -e "   Ô£ô FRPC Client installato e configurato"        
echo -e "   Ô£ô Tunnel attivo: $FRP_SERVER:$REMOTE_PORT ÔåÆ localhost:6556"    fi
echo -e "\n${CYAN}­ƒöº COMANDI UTILI:${NC}"    
echo -e "   Test agent locale:    ${YELLOW}/usr/bin/check_mk_agent${NC}"    
echo -e "   Status socket:        ${YELLOW}systemctl status check-mk-agent-plain.socket${NC}"        if [ "$INSTALL_FRPC" = "yes" ]; then
    echo -e "   Status FRPC:          ${YELLOW}systemctl status frpc${NC}"        
echo -e "   Log FRPC:             ${YELLOW}journalctl -u frpc -f${NC}"        
echo -e "   Config FRPC:          ${YELLOW}/etc/frp/frpc.toml${NC}"    fi
echo -e "\n${GREEN}­ƒÄë Installazione terminata con successo!${NC}\n"}
# =====================================================
# MAIN SCRIPT
# =====================================================
# Verifica permessi root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Ô£ù Questo script deve essere eseguito come root${NC}"
    exit 1
fi # Rileva sistema operativodetect_os
# =====================================================
# CONFERMA INIZIALE - Mostra SO rilevato
# =====================================================
echo -e "\n${CYAN}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"
echo -e "${CYAN}Ôòæ             RILEVAMENTO SISTEMA OPERATIVO                 Ôòæ${NC}"
echo -e "${CYAN}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"
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
echo -e "\n${YELLOW}Questa installazione utilizzer├á:${NC}"
echo -e "   ÔÇó CheckMK Agent (plain TCP on port 6556)"
echo -e "   ÔÇó Servizio: $([ "$PKG_TYPE" = "openwrt" ] && 
echo "init.d" || 
echo "systemd socket")"if [ "$PKG_TYPE" = "openwrt" ]; then
    echo -e "   ÔÇó TCP Listener: socat"
fi
echo -e "\n${YELLOW}ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ${NC}"read -r -p "$(
echo -e ${CYAN}Procedi con l\"installazione su questo sistema? ${NC}[s/N]: )" CONFIRM_SYSTEM
echo -e "${YELLOW}ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ${NC}"if [[ ! "$CONFIRM_SYSTEM" =~ ^[sS]$ ]]; then
    echo -e "\n${CYAN}Installazione annullata dall\"utente${NC}\n"
    exit 0
fi echo -e "\n${GREEN}Proceden
do con l\"installazione...${NC}\n"
# Installa CheckMK Agentinstall_checkmk_agent
# Configura agent plainconfigure_plain_agent
# Chiedi se installare FRPC
echo -e "\n${YELLOW}ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ${NC}"read -r -p "$(
echo -e ${CYAN}Vuoi installare anche FRPC? ${NC}[s/N]: )" INSTALL_FRPC_INPUT
echo -e "${YELLOW}ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ${NC}"
INSTALL_FRPC="no"
if [[ "$INSTALL_FRPC_INPUT" =~ ^[sS]$ ]]; then
    INSTALL_FRPC="yes"    install_frpc    configure_frpc
else    
echo -e "${YELLOW}ÔÅ¡´©Å  Installazione FRPC saltata${NC}"fi
# Mostra riepilogo finaleshow_summaryexit 0

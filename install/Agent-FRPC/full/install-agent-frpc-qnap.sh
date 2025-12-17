#!/bin/bash
# =====================================================
# Script Installazione CheckMK Agent + FRPC per QNAP NAS
# - Installazione ottimizzata per QNAP QTS/QuTS
# - Gestione agent CheckMK in modalit├á plain (TCP 6556)
# - Configurazione FRPC client per tunnel
# - Supporto autostart tramite autorun.sh
# - Compatibile con QNAP QTS 4.x e 5.x
# =====================================================
# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' 
# No Color
# Variabili globali
CHECKMK_VERSION="2.4.0p12"
FRP_VERSION="0.64.0"
FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz"
# Directory QNAP specifiche
QNAP_AUTORUN="/etc/config/autorun.sh"
QNAP_INSTALL_DIR="/share/CACHEDEV1_DATA/.qpkg"
AGENT_DIR="/opt/checkmk"
FRPC_DIR="/opt/frpc"
# Modalit├á operativa
MODE="install"
# =====================================================
# Funzione: Check se processo ├¿ attivo (compatibile senza pgrep)
# =====================================================is_process_running() {    local pattern="$1"    if command -v pgrep >/dev/null 2>&1; then        pgrep -f "$pattern" >/dev/null 2>&1    else        ps aux 2>/dev/null | grep -v grep | grep -q "$pattern"    fi}
# =====================================================
# Funzione: Kill processo (compatibile senza pkill)
# =====================================================kill_process() {    local pattern="$1"    if command -v pkill >/dev/null 2>&1; then        pkill -f "$pattern" 2>/dev/null    else        
# Usa ps + grep + cut per ottenere i PID        ps aux 2>/dev/null | grep -v grep | grep "$pattern" | while read -r line; do            pid=$(
echo "$line" | tr -s ' ' | cut -d' ' -f2)            [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null        done    fi}
# =====================================================
# Funzione: Banner
# =====================================================show_banner() {    
echo -e "${CYAN}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"    
echo -e "${CYAN}Ôòæ  Installazione CheckMK Agent + FRPC per NAS/Linux        Ôòæ${NC}"    
echo -e "${CYAN}Ôòæ  Version: 1.0 - $(date +%Y-%m-%d)                                Ôòæ${NC}"    
echo -e "${CYAN}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"    
echo ""}
# =====================================================
# Funzione: Mostra uso
# =====================================================show_usage() {    show_banner    
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
echo -e "${CYAN}Requisiti:${NC}"    
echo -e "  ÔÇó QNAP (QTS 4.x/5.x), Nethesis NAS o sistema Linux compatibile"    
echo -e "  ÔÇó Accesso SSH attivo"    
echo -e "  ÔÇó Utente admin o root"    
echo -e "  ÔÇó Almeno 100MB di spazio disco disponibile"    
echo ""    exit 0}
# =====================================================
# Funzione: Verifica sistema QNAP/NAS
# =====================================================check_qnap_system() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ VERIFICA SISTEMA NAS ÔòÉÔòÉÔòÉ${NC}"        
# Rileva tipo di NAS    
NAS_TYPE="generic"        if [ -f /etc/config/uLinux.conf ]; then        
NAS_TYPE="qnap"        
QTS_VERSION=$(grep -oP '
NAS_VERSION="\K[^"]+' /etc/config/uLinux.conf 2>/dev/null || 
echo "Unknown")        
echo -e "${GREEN}Ô£ô QNAP NAS rilevato${NC}"        
echo -e "   QTS Version: ${CYAN}$QTS_VERSION${NC}"    elif [ -f /etc/nethserver-release ]; then        
NAS_TYPE="nethesis"        
echo -e "${GREEN}Ô£ô Nethesis NAS rilevato${NC}"        if [ -f /etc/nethserver-release ]; then            cat /etc/nethserver-release        fi    elif [ -d /share/CACHEDEV1_DATA ] || [ -d /share/MD0_DATA ]; then        
NAS_TYPE="qnap-like"        
echo -e "${GREEN}Ô£ô Sistema compatibile QNAP rilevato${NC}"    else        
echo -e "${YELLOW}ÔÜá´©Å  Sistema NAS generico rilevato${NC}"        
echo -e "${YELLOW}   Lo script continuer├á con configurazione generica${NC}"    fi        
# Rileva architettura    
ARCH=$(uname -m)    
echo -e "   Architettura: ${CYAN}$ARCH${NC}"        
# Verifica se l'architettura ├¿ supportata    if [[ "$ARCH" != "x86_64" ]] && [[ "$ARCH" != "aarch64" ]]; then        
echo -e "${YELLOW}ÔÜá´©Å  Architettura $ARCH potrebbe non essere completamente supportata${NC}"        
echo -e "${YELLOW}   Lo script continuer├á ma potrebbero esserci problemi${NC}"        
echo -n "   Continuare comunque? [s/N]: "        read -r CONFIRM        if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then            exit 1        fi    fi        
# Verifica spazio disco - prova diverse directory    
AVAILABLE_SPACE="0"    if [ -d /share/CACHEDEV1_DATA ]; then        
AVAILABLE_SPACE=$(df -BM /share/CACHEDEV1_DATA 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/M//' || 
echo "0")    elif [ -d /share/MD0_DATA ]; then        
AVAILABLE_SPACE=$(df -BM /share/MD0_DATA 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/M//' || 
echo "0")    else        
AVAILABLE_SPACE=$(df -BM /opt 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/M//' || 
echo "1000")    fi        
# Rimuovi eventuali caratteri non numerici    
AVAILABLE_SPACE=$(
echo "$AVAILABLE_SPACE" | grep -oE '[0-9]+' || 
echo "1000")        if [ "$AVAILABLE_SPACE" -lt 100 ]; then        
echo -e "${YELLOW}ÔÜá´©Å  Spazio disco limitato: ${AVAILABLE_SPACE}MB${NC}"        
echo -e "${YELLOW}   Continuare comunque? Lo script richiede almeno 100MB${NC}"        
echo -n "   Continuare? [s/N]: "        read -r CONFIRM        if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then            exit 1        fi    else        
echo -e "   Spazio disponibile: ${GREEN}${AVAILABLE_SPACE}MB${NC}"    fi}
# =====================================================
# Funzione: Installa dipendenze
# =====================================================install_dependencies() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ VERIFICA DIPENDENZE ÔòÉÔòÉÔòÉ${NC}"        
# Verifica wget    if ! command -v wget >/dev/null 2>&1; then        
echo -e "${YELLOW}ÔÜá´©Å  wget non trovato, tentativo installazione...${NC}"        if command -v opkg >/dev/null 2>&1; then            opkg update && opkg install wget        elif command -v yum >/dev/null 2>&1; then            yum install -y wget        elif command -v apt-get >/dev/null 2>&1; then            apt-get update && apt-get install -y wget        else            
echo -e "${RED}Ô£ù Impossibile installare wget${NC}"            exit 1        fi    else        
echo -e "${GREEN}Ô£ô wget disponibile${NC}"    fi        
# Verifica tar    if ! command -v tar >/dev/null 2>&1; then        
echo -e "${RED}Ô£ù tar non disponibile${NC}"        exit 1    else        
echo -e "${GREEN}Ô£ô tar disponibile${NC}"    fi        
# Verifica socat (necessario per agent plain)    if ! command -v socat >/dev/null 2>&1; then        
echo -e "${YELLOW}ÔÜá´©Å  socat non trovato, tentativo installazione...${NC}"                
# Prova diversi package manager        
SOCAT_INSTALLED=false                if command -v opkg >/dev/null 2>&1; then            
echo -e "${CYAN}   Usan
do opkg (QNAP/OpenWrt)...${NC}"            opkg update 2>&1 | grep -v "Signature check"            if opkg install socat 2>&1; then                
SOCAT_INSTALLED=true            fi        elif command -v yum >/dev/null 2>&1; then            
echo -e "${CYAN}   Usan
do yum (CentOS/RHEL)...${NC}"            if yum install -y socat 2>&1 | grep -v "^Loaded plugins"; then                
SOCAT_INSTALLED=true            fi        elif command -v dnf >/dev/null 2>&1; then            
echo -e "${CYAN}   Usan
do dnf (Fedora/RHEL 8+)...${NC}"            if dnf install -y socat 2>&1; then                
SOCAT_INSTALLED=true            fi        elif command -v apt-get >/dev/null 2>&1; then            
echo -e "${CYAN}   Usan
do apt-get (Debian/Ubuntu)...${NC}"            if apt-get update && apt-get install -y socat 2>&1; then                
SOCAT_INSTALLED=true            fi        else            
echo -e "${YELLOW}ÔÜá´©Å  Package manager non trovato, provo a rilevare il sistema...${NC}"                        
# Rileva sistema operativo            if [ -f /etc/redhat-release ] || [ -f /etc/centos-release ] || [ -f /etc/rocky-release ]; then                
echo -e "${CYAN}   Sistema RHEL-based rilevato, usan
do yum...${NC}"                if command -v yum >/dev/null 2>&1; then                    yum install -y socat 2>&1 | grep -v "^Loaded plugins"                    
SOCAT_INSTALLED=true                fi            elif [ -f /etc/debian_version ]; then                
echo -e "${CYAN}   Sistema Debian-based rilevato, usan
do apt...${NC}"                if command -v apt >/dev/null 2>&1; then                    apt update && apt install -y socat 2>&1                    
SOCAT_INSTALLED=true                fi            else                
echo -e "${RED}Ô£ù Impossibile determinare il package manager${NC}"            fi        fi                
# Verifica installazione        if ! command -v socat >/dev/null 2>&1; then            
echo -e "${YELLOW}ÔÜá´©Å  socat non disponibile, uso meto
do alternativo${NC}"            
echo -e "${GREEN}Ô£ô Useremo script bash standalone (netcat/bash nativo)${NC}"            
USE_STANDALONE_MODE=true        else            
echo -e "${GREEN}Ô£ô socat installato con successo${NC}"        fi    else        
echo -e "${GREEN}Ô£ô socat disponibile${NC}"    fi}
# =====================================================
# Funzione: Scarica agent CheckMK
# =====================================================download_checkmk_agent() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ DOWNLOAD CHECKMK AGENT ÔòÉÔòÉÔòÉ${NC}"        
# URL dello script agent (versione universale)    
AGENT_URL="https://monitoring.nethlab.it/monitoring/check_mk/agents/check_mk_agent.linux"        
echo -e "${YELLOW}­ƒôª Download agent v${CHECKMK_VERSION}...${NC}"    
echo -e "   URL: ${CYAN}$AGENT_URL${NC}"        cd /tmp || exit 1    rm -f check_mk_agent.linux 2>/dev/null        if wget -q --show-progress "$AGENT_URL" -O check_mk_agent.linux 2>&1; then        
echo -e "${GREEN}Ô£ô Download completato${NC}"    else        
echo -e "${RED}Ô£ù Errore durante il download dell'agent${NC}"        exit 1    fi        
# Verifica che il file sia vali
do    if [ ! -f check_mk_agent.linux ] || [ ! -s check_mk_agent.linux ]; then        
echo -e "${RED}Ô£ù File agent non vali
do o vuoto${NC}"        exit 1    fi        
# Verifica che sia uno script bash    if ! head -n 1 check_mk_agent.linux | grep -q "^
#!"; then        
echo -e "${RED}Ô£ù File scaricato non ├¿ uno script vali
do${NC}"        exit 1    fi        
echo -e "${GREEN}Ô£ô Agent scaricato e verificato${NC}"}
# =====================================================
# Funzione: Installa CheckMK Agent
# =====================================================install_checkmk_agent() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ INSTALLAZIONE CHECKMK AGENT ÔòÉÔòÉÔòÉ${NC}"        
# Crea directory    mkdir -p "$AGENT_DIR"    mkdir -p "$AGENT_DIR/bin"    mkdir -p "$AGENT_DIR/log"        
# Copia agent    
echo -e "${YELLOW}­ƒôª Installazione agent...${NC}"    cp /tmp/check_mk_agent.linux "$AGENT_DIR/bin/check_mk_agent"    chmod +x "$AGENT_DIR/bin/check_mk_agent"        
# Crea symlink in /usr/bin per compatibilit├á    ln -sf "$AGENT_DIR/bin/check_mk_agent" /usr/bin/check_mk_agent        
echo -e "${GREEN}Ô£ô Agent installato in $AGENT_DIR${NC}"        
# Test agent    
echo -e "\n${CYAN}­ƒôè Test agent locale:${NC}"    if "$AGENT_DIR/bin/check_mk_agent" | head -n 5; then        
echo -e "${GREEN}Ô£ô Agent funzionante${NC}"    else        
echo -e "${RED}Ô£ù Errore nel test dell'agent${NC}"        exit 1    fi}
# =====================================================
# Funzione: Configura servizio agent
# =====================================================configure_agent_service() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ CONFIGURAZIONE SERVIZIO AGENT ÔòÉÔòÉÔòÉ${NC}"        
# Usa standalone se impostato, altrimenti socat    if [ "${USE_STANDALONE_MODE:-false}" = "true" ]; then        configure_agent_standalone    else        configure_agent_socat    fi}
# =====================================================
# Funzione: Configura agent con socat
# =====================================================configure_agent_socat() {    
echo -e "${CYAN}Configurazione con socat...${NC}"        
# Crea script di avvio    cat > "$AGENT_DIR/start_agent.sh" <<'EOF'
#!/bin/bash
# Start CheckMK Agent on port 6556
AGENT_BIN="/opt/checkmk/bin/check_mk_agent"
LOG_FILE="/opt/checkmk/log/agent.log"
# Kill existing instanceskillall socat 2>/dev/null
# Start socat listener
echo "$(date): Starting CheckMK Agent on port 6556" >> "$LOG_FILE"socat TCP-LISTEN:6556,reuseaddr,fork EXEC:"$AGENT_BIN" 2>&1 | tee -a "$LOG_FILE" &
echo "CheckMK Agent started on port 6556"EOF        chmod +x "$AGENT_DIR/start_agent.sh"        
# Crea script di stop    cat > "$AGENT_DIR/stop_agent.sh" <<'EOF'
#!/bin/bash
# Stop CheckMK Agent
LOG_FILE="/opt/checkmk/log/agent.log"
echo "$(date): Stopping CheckMK Agent" >> "$LOG_FILE"killall socat 2>/dev/null
echo "CheckMK Agent stopped"EOF        chmod +x "$AGENT_DIR/stop_agent.sh"        
echo -e "${GREEN}Ô£ô Script di controllo creati (socat mode)${NC}"}
# =====================================================
# Funzione: Configura agent con xinetd
# =====================================================configure_agent_xinetd() {    
echo -e "${CYAN}Configurazione con xinetd...${NC}"        
# Verifica se xinetd ├¿ installato    if ! command -v xinetd >/dev/null 2>&1; then        
echo -e "${YELLOW}ÔÜá´©Å  xinetd non trovato, tentativo installazione...${NC}"                
XINETD_INSTALLED=false                if command -v opkg >/dev/null 2>&1; then            
echo -e "${CYAN}   Usan
do opkg...${NC}"            opkg update 2>&1 | grep -v "Signature check"            opkg install xinetd && 
XINETD_INSTALLED=true        elif command -v yum >/dev/null 2>&1; then            
echo -e "${CYAN}   Usan
do yum...${NC}"            yum install -y xinetd && 
XINETD_INSTALLED=true        elif command -v dnf >/dev/null 2>&1; then            
echo -e "${CYAN}   Usan
do dnf...${NC}"            dnf install -y xinetd && 
XINETD_INSTALLED=true        elif command -v apt-get >/dev/null 2>&1; then            
echo -e "${CYAN}   Usan
do apt-get...${NC}"            apt-get update && apt-get install -y xinetd && 
XINETD_INSTALLED=true        elif [ -f /etc/redhat-release ] || [ -f /etc/centos-release ] || [ -f /etc/rocky-release ]; then            
echo -e "${CYAN}   Sistema RHEL-based, usan
do yum...${NC}"            yum install -y xinetd && 
XINETD_INSTALLED=true        fi                if ! command -v xinetd >/dev/null 2>&1; then            
echo -e "${RED}Ô£ù Impossibile installare xinetd${NC}"            
echo -e "${YELLOW}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"            
echo -e "${YELLOW}Ôòæ  IMPOSSIBILE CONTINUARE SENZA SOCAT O XINETD             Ôòæ${NC}"            
echo -e "${YELLOW}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"            
echo -e ""            
echo -e "${RED}Il sistema non ha n├® socat n├® xinetd disponibili.${NC}"            
echo -e "${CYAN}Per installare manualmente:${NC}"            
echo -e ""            
echo -e "  ${GREEN}
# Per sistemi RHEL/CentOS/Rocky:${NC}"            
echo -e "  yum install -y epel-release"            
echo -e "  yum install -y xinetd socat"            
echo -e ""            
echo -e "  ${GREEN}
# Per sistemi QNAP con Entware:${NC}"            
echo -e "  opkg update"            
echo -e "  opkg install xinetd socat"            
echo -e ""            
echo -e "  ${GREEN}
# Poi riesegui questo script${NC}"            
echo -e ""            exit 1        else            
echo -e "${GREEN}Ô£ô xinetd installato con successo${NC}"        fi    fi        
# Crea directory xinetd.d se non esiste    mkdir -p /etc/xinetd.d        
# Crea configurazione xinetd    cat > /etc/xinetd.d/check_mk <<EOFservice check_mk{    type           = UNLISTED    port           = 6556    socket_type    = stream    protocol       = tcp    wait           = no    user           = root    server         = $AGENT_DIR/bin/check_mk_agent    disable        = no}EOF        
# Crea script di avvio    cat > "$AGENT_DIR/start_agent.sh" <<'EOF'
#!/bin/bash
# Start CheckMK Agent via xinetd
LOG_FILE="/opt/checkmk/log/agent.log"
echo "$(date): Starting CheckMK Agent via xinetd" >> "$LOG_FILE"
# Restart xinetd
if [ -f /etc/init.d/xinetd ]; then    /etc/init.d/xinetd restart
elif command -v systemctl >/dev/null 2>&1; then    systemctl restart xinetd
else    killall xinetd 2>/dev/null    xinetd
fi
echo "CheckMK Agent started via xinetd on port 6556"EOF        chmod +x "$AGENT_DIR/start_agent.sh"        
# Crea script di stop    cat > "$AGENT_DIR/stop_agent.sh" <<'EOF'
#!/bin/bash
# Stop CheckMK Agent
LOG_FILE="/opt/checkmk/log/agent.log"
echo "$(date): Stopping CheckMK Agent (xinetd)" >> "$LOG_FILE"
# Remove xinetd configrm -f /etc/xinetd.d/check_mk
# Restart xinetd
if [ -f /etc/init.d/xinetd ]; then    /etc/init.d/xinetd restart
elif command -v systemctl >/dev/null 2>&1; then    systemctl restart xinetd
fi
echo "CheckMK Agent stopped"EOF        chmod +x "$AGENT_DIR/stop_agent.sh"        
echo -e "${GREEN}Ô£ô Configurazione xinetd creata${NC}"}
# =====================================================
# Funzione: Configura agent con systemd socket
# =====================================================configure_agent_systemd() {    
echo -e "${CYAN}Configurazione con systemd socket...${NC}"        
# Verifica che systemd sia disponibile    if ! command -v systemctl >/dev/null 2>&1; then        
echo -e "${RED}Ô£ù systemd non disponibile${NC}"        exit 1    fi        
echo -e "${GREEN}Ô£ô systemd rilevato${NC}"        
# Crea unit socket    cat > /etc/systemd/system/check-mk-agent-plain.socket <<EOF[Unit]Description=CheckMK Agent Socket (Plain TCP 6556)Documentation=https://docs.checkmk.com/[Socket]ListenStream=6556Accept=yes[Install]WantedBy=sockets.targetEOF        
# Crea unit service    cat > /etc/systemd/system/check-mk-agent-plain@.service <<EOF[Unit]Description=CheckMK Agent Plain ConnectionDocumentation=https://docs.checkmk.com/[Service]Type=simpleExecStart=$AGENT_DIR/bin/check_mk_agentStandardInput=socketUser=rootEOF        
# Crea script di avvio    cat > "$AGENT_DIR/start_agent.sh" <<'EOF'
#!/bin/bash
# Start CheckMK Agent via systemd socket
LOG_FILE="/opt/checkmk/log/agent.log"
echo "$(date): Starting CheckMK Agent via systemd socket" >> "$LOG_FILE"
# Reload systemdsystemctl daemon-reload
# Enable and start socketsystemctl enable check-mk-agent-plain.socketsystemctl start check-mk-agent-plain.socket
echo "CheckMK Agent started via systemd on port 6556"EOF        chmod +x "$AGENT_DIR/start_agent.sh"        
# Crea script di stop    cat > "$AGENT_DIR/stop_agent.sh" <<'EOF'
#!/bin/bash
# Stop CheckMK Agent
LOG_FILE="/opt/checkmk/log/agent.log"
echo "$(date): Stopping CheckMK Agent (systemd)" >> "$LOG_FILE"
# Stop and disable socketsystemctl stop check-mk-agent-plain.socketsystemctl disable check-mk-agent-plain.socket
echo "CheckMK Agent stopped"EOF        chmod +x "$AGENT_DIR/stop_agent.sh"        
# Reload systemd    systemctl daemon-reload        
echo -e "${GREEN}Ô£ô Configurazione systemd socket creata${NC}"}
# =====================================================
# Funzione: Configura agent con script standalone
# =====================================================configure_agent_standalone() {    
echo -e "${CYAN}Configurazione con script bash standalone...${NC}"        
# Crea script daemon che ascolta sulla porta    cat > "$AGENT_DIR/agent_daemon.sh" <<'EOF'
#!/bin/bash
# CheckMK Agent Daemon - Standalone TCP listener
# Ottimizzato per QNAP con Python 2.7+ compatibilit├á
AGENT_BIN="/opt/checkmk/bin/check_mk_agent"
PORT=6556
LOG_FILE="/opt/checkmk/log/agent.log"
PID_FILE="/var/run/checkmk_agent.pid"log_msg() {    
echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE" 2>/dev/null || true}
# Prova socat per primo (il migliore)if command -v socat >/dev/null 2>&1; then    log_msg "Starting agent daemon with socat on port $PORT"    while true; do        socat TCP-LISTEN:$PORT,reuseaddr,fork EXEC:"$AGENT_BIN" 2>>"$LOG_FILE" || sleep 1    done
# Altrimenti usa Python (compatibile con Python 2.7+)elif command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then    log_msg "Starting agent daemon with Python on port $PORT"        
PYTHON_CMD=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)        $PYTHON_CMD -u << 'PYTHON_EOF'import socketimport subprocessimport sysPORT = 6556AGENT_BIN = "/opt/checkmk/bin/check_mk_agent"def handle_client(client_socket):    try:        
# Python 2.7 compatible subprocess call        proc = subprocess.Popen([AGENT_BIN], stdout=subprocess.PIPE, stderr=subprocess.PIPE)        output, _ = proc.communicate()        client_socket.sendall(output)    except Exception as e:        sys.stderr.write("Error handling client: " + str(e) + "\n")    finally:        try:            client_socket.close()        except:            passdef main():    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)    server.bind(('0.0.0.0', PORT))    server.listen(5)        print("CheckMK Agent listening on port " + str(PORT))    sys.stdout.flush()        while True:        try:            client, addr = server.accept()            handle_client(client)        except KeyboardInterrupt:            break        except Exception as e:            sys.stderr.write("Error: " + str(e) + "\n")            continue        server.close()if __name__ == "__main__":    main()PYTHON_EOF
# Fallback con xinetd se disponibile
elif [ -f /etc/xinetd.d/ ] && command -v xinetd >/dev/null 2>&1; then    log_msg "Configuring xinetd for CheckMK agent"    cat > /etc/xinetd.d/checkmk <<XINETD_EOFservice checkmk{    type           = UNLISTED    port           = $PORT    socket_type    = stream    protocol       = tcp    wait           = no    user           = root    server         = $AGENT_BIN    disable        = no}XINETD_EOF        /etc/init.d/xinetd restart    log_msg "Agent configured via xinetd"        
# Loop per mantenere lo script attivo    while true; do        sleep 3600    done
else    
# Ultimo fallback: netcat detection migliorato    log_msg "No socat or Python found, trying netcat alternatives"        
# Cerca tutte le possibili varianti di netcat    for NC_CMD in netcat ncat nc.traditional /usr/bin/nc /bin/nc; do        if command -v $NC_CMD >/dev/null 2>&1; then            
# Test se supporta -l (listen)            if $NC_CMD -h 2>&1 | grep -qi "listen"; then                log_msg "Using $NC_CMD"                while true; do                    $NC_CMD -l -p $PORT -e "$AGENT_BIN" 2>/dev/null || \                    $NC_CMD -l $PORT -e "$AGENT_BIN" 2>/dev/null || \                    $NC_CMD -l -p $PORT -c "$AGENT_BIN" 2>/dev/null || \                    sleep 1                done            fi        fi    done        log_msg "ERROR: No suitable method found to listen on TCP port"    exit 1fiEOF        chmod +x "$AGENT_DIR/agent_daemon.sh"        
# Crea script di avvio    cat > "$AGENT_DIR/start_agent.sh" <<'EOFSTART'
#!/bin/bash
# Start CheckMK Agent Standalone Daemon
DAEMON="/opt/checkmk/agent_daemon.sh"
LOG_FILE="/opt/checkmk/log/agent.log"
PID_FILE="/var/run/checkmk_agent.pid"
# Kill existing instances (compatibile senza pkill)if command -v pkill >/dev/null 2>&1; then    pkill -f "agent_daemon.sh" 2>/dev/null    pkill -f "nc.*6556" 2>/dev/null
else    ps aux 2>/dev/null | grep -v grep | grep "agent_daemon.sh" | while read line; do        pid=$(
echo "$line" | tr -s ' ' | cut -d' ' -f2)        [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null    done    ps aux 2>/dev/null | grep -v grep | grep "nc.*6556" | while read line; do        pid=$(
echo "$line" | tr -s ' ' | cut -d' ' -f2)        [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null    done
fi
# Start daemon in background (senza nohup per compatibilit├á QNAP)
echo "$(date): Starting CheckMK Agent Standalone Daemon" >> "$LOG_FILE"
if command -v nohup >/dev/null 2>&1; then    nohup "$DAEMON" >> "$LOG_FILE" 2>&1 &else    
# Fallback senza nohup    "$DAEMON" >> "$LOG_FILE" 2>&1 </dev/null &fi
echo $! > "$PID_FILE"
echo "CheckMK Agent Standalone Daemon started on port 6556 with PID $(cat $PID_FILE)"EOFSTART        chmod +x "$AGENT_DIR/start_agent.sh"        
# Crea script di stop    cat > "$AGENT_DIR/stop_agent.sh" <<'EOF'
#!/bin/bash
# Stop CheckMK Agent Standalone Daemon
LOG_FILE="/opt/checkmk/log/agent.log"
PID_FILE="/var/run/checkmk_agent.pid"
echo "$(date): Stopping CheckMK Agent Standalone Daemon" >> "$LOG_FILE"
# Kill daemon (compatibile senza pkill)if command -v pkill >/dev/null 2>&1; then    pkill -f "agent_daemon.sh" 2>/dev/null    pkill -f "nc.*6556" 2>/dev/null    pkill -f "ncat.*6556" 2>/dev/null
else    ps aux 2>/dev/null | grep -v grep | grep "agent_daemon.sh" | while read line; do        pid=$(
echo "$line" | tr -s ' ' | cut -d' ' -f2)        [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null    done    ps aux 2>/dev/null | grep -v grep | grep "nc.*6556" | while read line; do        pid=$(
echo "$line" | tr -s ' ' | cut -d' ' -f2)        [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null    done    ps aux 2>/dev/null | grep -v grep | grep "ncat.*6556" | while read line; do        pid=$(
echo "$line" | tr -s ' ' | cut -d' ' -f2)        [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null    done
fi
# Remove PID filerm -f "$PID_FILE"
echo "CheckMK Agent Standalone Daemon stopped"EOF        chmod +x "$AGENT_DIR/stop_agent.sh"        
echo -e "${GREEN}Ô£ô Configurazione standalone creata${NC}"    
echo -e "${CYAN}  Questo meto
do usa netcat o bash puro, nessuna dipendenza richiesta${NC}"}
# =====================================================
# Funzione: Scarica e installa FRPC
# =====================================================install_frpc() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ INSTALLAZIONE FRPC CLIENT ÔòÉÔòÉÔòÉ${NC}"        
# Adatta URL in base all'architettura    if [[ "$ARCH" == "aarch64" ]]; then        
FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_arm64.tar.gz"        
FRP_ARCHIVE="frp_${FRP_VERSION}_linux_arm64.tar.gz"        
FRP_FOLDER="frp_${FRP_VERSION}_linux_arm64"    else        
FRP_ARCHIVE="frp_${FRP_VERSION}_linux_amd64.tar.gz"        
FRP_FOLDER="frp_${FRP_VERSION}_linux_amd64"    fi        
echo -e "${YELLOW}­ƒôª Download FRPC v${FRP_VERSION} per $ARCH...${NC}"    
echo -e "   URL: ${CYAN}$FRP_URL${NC}"        cd /tmp || exit 1    rm -f "$FRP_ARCHIVE" 2>/dev/null    rm -rf "$FRP_FOLDER" 2>/dev/null        if wget -q --show-progress "$FRP_URL" -O "$FRP_ARCHIVE" 2>&1; then        
echo -e "${GREEN}Ô£ô Download completato${NC}"    else        
echo -e "${RED}Ô£ù Errore durante il download di FRPC${NC}"        exit 1    fi        
# Estrai archivio    
echo -e "${YELLOW}­ƒôª Estrazione archivio...${NC}"    tar -xzf "$FRP_ARCHIVE" || {        
echo -e "${RED}Ô£ù Errore durante l'estrazione${NC}"        exit 1    }        
# Crea directory FRPC    mkdir -p "$FRPC_DIR/bin"    mkdir -p "$FRPC_DIR/conf"    mkdir -p "$FRPC_DIR/log"        
# Copia eseguibile    
echo -e "${YELLOW}­ƒôª Installazione FRPC...${NC}"    cp "$FRP_FOLDER/frpc" "$FRPC_DIR/bin/frpc"    chmod +x "$FRPC_DIR/bin/frpc"        
# Crea symlink    ln -sf "$FRPC_DIR/bin/frpc" /usr/local/bin/frpc        
# Cleanup    rm -rf "$FRP_FOLDER" "$FRP_ARCHIVE"        
echo -e "${GREEN}Ô£ô FRPC installato in $FRPC_DIR${NC}"        
# Verifica versione    
echo -e "\n${CYAN}­ƒôè Versione FRPC:${NC}"    "$FRPC_DIR/bin/frpc" --version}
# =====================================================
# Funzione: Configura FRPC
# =====================================================configure_frpc() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ CONFIGURAZIONE FRPC ÔòÉÔòÉÔòÉ${NC}"        
# Hostname corrente come default    
CURRENT_HOSTNAME=$(hostname 2>/dev/null || 
echo "qnap-host")        
echo -e "${YELLOW}Inserisci le informazioni per la configurazione FRPC:${NC}\n"        
# Nome host    
echo -ne "${CYAN}Nome host ${NC}[default: $CURRENT_HOSTNAME]: "    read -r FRPC_HOSTNAME    
FRPC_HOSTNAME=${FRPC_HOSTNAME:-$CURRENT_HOSTNAME}        
# Server remoto    
echo -ne "${CYAN}Server FRP remoto ${NC}[default: monitor.nethlab.it]: "    read -r FRP_SERVER    
FRP_SERVER=${FRP_SERVER:-"monitor.nethlab.it"}        
# Porta remota    
echo -ne "${CYAN}Porta remota ${NC}[es: 20001]: "    read -r REMOTE_PORT    while [ -z "$REMOTE_PORT" ]; do        
echo -e "${RED}Ô£ù Porta remota obbligatoria!${NC}"        
echo -ne "${CYAN}Porta remota: ${NC}"        read -r REMOTE_PORT    done        
# Token di sicurezza    
echo -ne "${CYAN}Token di sicurezza ${NC}[default: conduit-reenact-talon-macarena-demotion-vaguely]: "    read -r AUTH_TOKEN    
AUTH_TOKEN=${AUTH_TOKEN:-"conduit-reenact-talon-macarena-demotion-vaguely"}        
# Crea directory config    mkdir -p "$FRPC_DIR/conf"        
# Genera configurazione TOML    
echo -e "\n${YELLOW}­ƒôØ Creazione file configurazione FRPC...${NC}"        cat > "$FRPC_DIR/conf/frpc.toml" <<EOF
# Configurazione FRPC Client
# Generato il $(date)[common]server_addr = "$FRP_SERVER"server_port = 7000auth.method = "token"auth.token  = "$AUTH_TOKEN"tls.enable = truelog.to = "$FRPC_DIR/log/frpc.log"log.level = "info"[$FRPC_HOSTNAME]type        = "tcp"local_ip    = "127.0.0.1"local_port  = 6556remote_port = $REMOTE_PORTEOF        
echo -e "${GREEN}Ô£ô File di configurazione creato${NC}"        
# Mostra configurazione    
echo -e "\n${CYAN}­ƒôï Configurazione FRPC:${NC}"    
echo -e "   Server:       ${GREEN}$FRP_SERVER:7000${NC}"    
echo -e "   Tunnel:       ${GREEN}$FRPC_HOSTNAME${NC}"    
echo -e "   Porta remota: ${GREEN}$REMOTE_PORT${NC}"    
echo -e "   Porta locale: ${GREEN}6556${NC}"    
echo -e "   Config file:  ${GREEN}$FRPC_DIR/conf/frpc.toml${NC}"        
# Crea script di avvio FRPC    cat > "$FRPC_DIR/start_frpc.sh" <<'EOFSTART'
#!/bin/bash
# Start FRPC Client
FRPC_BIN="/opt/frpc/bin/frpc"
FRPC_CONF="/opt/frpc/conf/frpc.toml"
LOG_FILE="/opt/frpc/log/startup.log"
PID_FILE="/var/run/frpc.pid"
# Kill existing instances (compatibile senza pkill)if command -v pkill >/dev/null 2>&1; then    pkill -f "frpc -c" 2>/dev/null
else    ps aux 2>/dev/null | grep -v grep | grep "frpc -c" | while read line; do        pid=$(
echo "$line" | tr -s ' ' | cut -d' ' -f2)        [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null    done
fi
# Start FRPC (senza nohup per compatibilit├á QNAP)
echo "$(date): Starting FRPC client" >> "$LOG_FILE"
if command -v nohup >/dev/null 2>&1; then    nohup "$FRPC_BIN" -c "$FRPC_CONF" >> "$LOG_FILE" 2>&1 &else    
# Fallback senza nohup    "$FRPC_BIN" -c "$FRPC_CONF" >> "$LOG_FILE" 2>&1 </dev/null &fi
echo $! > "$PID_FILE"
echo "FRPC client started with PID $(cat $PID_FILE)"EOFSTART        chmod +x "$FRPC_DIR/start_frpc.sh"        
# Crea script di stop FRPC    cat > "$FRPC_DIR/stop_frpc.sh" <<'EOFSTOP'
#!/bin/bash
# Stop FRPC Client
LOG_FILE="/opt/frpc/log/startup.log"
PID_FILE="/var/run/frpc.pid"
echo "$(date): Stopping FRPC client" >> "$LOG_FILE"
# Kill process (compatibile senza pkill)if command -v pkill >/dev/null 2>&1; then    pkill -f "frpc -c" 2>/dev/null
else    ps aux 2>/dev/null | grep -v grep | grep "frpc -c" | while read line; do        pid=$(
echo "$line" | tr -s ' ' | cut -d' ' -f2)        [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null    done
fi
# Remove PID filerm -f "$PID_FILE"
echo "FRPC client stopped"EOFSTOP        chmod +x "$FRPC_DIR/stop_frpc.sh"        
echo -e "${GREEN}Ô£ô Script di controllo FRPC creati${NC}"}
# =====================================================
# Funzione: Configura autostart QNAP
# =====================================================configure_autostart() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ CONFIGURAZIONE AUTOSTART ÔòÉÔòÉÔòÉ${NC}"        
# Backup autorun.sh se esiste    if [ -f "$QNAP_AUTORUN" ]; then        cp "$QNAP_AUTORUN" "${QNAP_AUTORUN}.backup.$(date +%Y%m%d_%H%M%S)"        
echo -e "${YELLOW}Ô£ô Backup di autorun.sh creato${NC}"    fi        
# Rimuovi vecchie entries se presenti    if [ -f "$QNAP_AUTORUN" ]; then        sed -i '/
# CheckMK Agent autostart/,/
# End CheckMK Agent/d' "$QNAP_AUTORUN"        sed -i '/
# FRPC Client autostart/,/
# End FRPC Client/d' "$QNAP_AUTORUN"    fi        
# Crea o aggiorna autorun.sh    if [ ! -f "$QNAP_AUTORUN" ]; then        cat > "$QNAP_AUTORUN" <<'EOF'
#!/bin/sh
# QNAP Autorun ScriptEOF        chmod +x "$QNAP_AUTORUN"    fi        
# Aggiungi startup per CheckMK Agent    cat >> "$QNAP_AUTORUN" <<EOF
# CheckMK Agent autostart
if [ -f "$AGENT_DIR/start_agent.sh" ]; then    sleep 10    $AGENT_DIR/start_agent.sh
fi
# End CheckMK AgentEOF        
# Aggiungi startup per FRPC se installato    if [ "$INSTALL_FRPC" = "yes" ]; then        cat >> "$QNAP_AUTORUN" <<EOF
# FRPC Client autostart
if [ -f "$FRPC_DIR/start_frpc.sh" ]; then    sleep 15    $FRPC_DIR/start_frpc.sh
fi
# End FRPC ClientEOF    fi        chmod +x "$QNAP_AUTORUN"        
echo -e "${GREEN}Ô£ô Autostart configurato${NC}"    
echo -e "   File: ${CYAN}$QNAP_AUTORUN${NC}"}
# =====================================================
# Funzione: Avvia servizi
# =====================================================start_services() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ AVVIO SERVIZI ÔòÉÔòÉÔòÉ${NC}"        
# Avvia CheckMK Agent    
echo -e "${YELLOW}­ƒÜÇ Avvio CheckMK Agent...${NC}"    "$AGENT_DIR/start_agent.sh"    sleep 2        
# Verifica in base al meto
do usato    if [ "${USE_STANDALONE_MODE:-false}" = "true" ]; then        if is_process_running "agent_daemon.sh" || is_process_running "nc.*6556"; then            
echo -e "${GREEN}Ô£ô CheckMK Agent attivo su porta 6556 (standalone daemon)${NC}"        else            
echo -e "${YELLOW}ÔÜá´©Å  Agent daemon potrebbe non essere attivo${NC}"        fi    else        if is_process_running "socat.*6556"; then            
echo -e "${GREEN}Ô£ô CheckMK Agent attivo su porta 6556 (socat)${NC}"        else            
echo -e "${YELLOW}ÔÜá´©Å  CheckMK Agent potrebbe non essere attivo${NC}"        fi    fi        
# Avvia FRPC se richiesto    if [ "$INSTALL_FRPC" = "yes" ]; then        
echo -e "${YELLOW}­ƒÜÇ Avvio FRPC Client...${NC}"        "$FRPC_DIR/start_frpc.sh"        sleep 3                if is_process_running "frpc"; then            
echo -e "${GREEN}Ô£ô FRPC Client attivo${NC}"        else            
echo -e "${RED}Ô£ù FRPC Client non avviato${NC}"        fi    fi}
# =====================================================
# Funzione: Test finale
# =====================================================run_tests() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ TEST FINALE ÔòÉÔòÉÔòÉ${NC}"        
# Test agent locale    
echo -e "\n${CYAN}­ƒôè Test CheckMK Agent locale:${NC}"    if /usr/bin/check_mk_agent | head -n 10; then        
echo -e "${GREEN}Ô£ô Agent risponde correttamente${NC}"    else        
echo -e "${RED}Ô£ù Agent non risponde${NC}"    fi        
# Test porta 6556    
echo -e "\n${CYAN}­ƒôè Test porta 6556:${NC}"    if 
echo "exit" | timeout 2 nc localhost 6556 2>/dev/null | head -n 3; then        
echo -e "${GREEN}Ô£ô Porta 6556 accessibile${NC}"    else        
echo -e "${YELLOW}ÔÜá´©Å  Porta 6556 non risponde (potrebbe essere normale)${NC}"    fi        
# Test FRPC se installato    if [ "$INSTALL_FRPC" = "yes" ]; then        
echo -e "\n${CYAN}­ƒôè Test FRPC:${NC}"        if is_process_running "frpc"; then            
echo -e "${GREEN}Ô£ô Processo FRPC attivo${NC}"            
echo -e "   Verifica log: ${CYAN}$FRPC_DIR/log/frpc.log${NC}"        else            
echo -e "${RED}Ô£ù Processo FRPC non attivo${NC}"        fi    fi}
# =====================================================
# Funzione: Riepilogo installazione
# =====================================================show_summary() {    
echo -e "\n${GREEN}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"    
echo -e "${GREEN}Ôòæ              INSTALLAZIONE COMPLETATA                     Ôòæ${NC}"    
echo -e "${GREEN}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"    
echo ""    
echo -e "${CYAN}­ƒôï Informazioni installazione:${NC}"    
echo -e "   ÔÇó Tipo sistema: ${YELLOW}$NAS_TYPE${NC}"    
echo -e "   ÔÇó Agent directory: ${YELLOW}$AGENT_DIR${NC}"    
echo -e "   ÔÇó Agent porta: ${YELLOW}6556 (TCP)${NC}"        
# Mostra il meto
do di avvio usato    if [ "${USE_STANDALONE_MODE:-false}" = "true" ]; then        
echo -e "   ÔÇó Meto
do avvio: ${YELLOW}standalone daemon (netcat/bash)${NC}"    else        
echo -e "   ÔÇó Meto
do avvio: ${YELLOW}socat${NC}"    fi        if [ -f "$QNAP_AUTORUN" ]; then        
echo -e "   ÔÇó Autostart: ${YELLOW}$QNAP_AUTORUN${NC}"    fi        if [ "$INSTALL_FRPC" = "yes" ]; then        
echo -e "   ÔÇó FRPC directory: ${YELLOW}$FRPC_DIR${NC}"        
echo -e "   ÔÇó FRPC config: ${YELLOW}$FRPC_DIR/conf/frpc.toml${NC}"        
echo -e "   ÔÇó FRPC porta remota: ${YELLOW}$REMOTE_PORT${NC}"    fi        
echo ""    
echo -e "${CYAN}­ƒöº Comandi utili:${NC}"    
echo -e "   ÔÇó Avvia agent:  ${YELLOW}$AGENT_DIR/start_agent.sh${NC}"    
echo -e "   ÔÇó Ferma agent:  ${YELLOW}$AGENT_DIR/stop_agent.sh${NC}"        if [ "$INSTALL_FRPC" = "yes" ]; then        
echo -e "   ÔÇó Avvia FRPC:   ${YELLOW}$FRPC_DIR/start_frpc.sh${NC}"        
echo -e "   ÔÇó Ferma FRPC:   ${YELLOW}$FRPC_DIR/stop_frpc.sh${NC}"        
echo -e "   ÔÇó Log FRPC:     ${YELLOW}tail -f $FRPC_DIR/log/frpc.log${NC}"    fi        
echo -e "   ÔÇó Test agent:   ${YELLOW}/usr/bin/check_mk_agent${NC}"    
echo ""    
echo -e "${GREEN}Ô£ô I servizi si avvieranno automaticamente al prossimo riavvio${NC}"    
echo ""}
# =====================================================
# Funzione: Disinstalla Agent
# =====================================================uninstall_agent() {    
echo -e "\n${RED}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"    
echo -e "${RED}Ôòæ        DISINSTALLAZIONE CHECKMK AGENT                     Ôòæ${NC}"    
echo -e "${RED}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"        
echo -e "\n${YELLOW}­ƒùæ´©Å  Rimozione CheckMK Agent...${NC}\n"        
# Stop servizio    if [ -f "$AGENT_DIR/stop_agent.sh" ]; then        "$AGENT_DIR/stop_agent.sh"    fi        killall socat 2>/dev/null || true        
# Rimuovi directory    if [ -d "$AGENT_DIR" ]; then        rm -rf "$AGENT_DIR"        
echo -e "${GREEN}Ô£ô Directory agent rimossa${NC}"    fi        
# Rimuovi symlink    if [ -L /usr/bin/check_mk_agent ]; then        rm -f /usr/bin/check_mk_agent        
echo -e "${GREEN}Ô£ô Symlink rimosso${NC}"    fi        
# Rimuovi da autorun    if [ -f "$QNAP_AUTORUN" ]; then        sed -i '/
# CheckMK Agent autostart/,/
# End CheckMK Agent/d' "$QNAP_AUTORUN"        
echo -e "${GREEN}Ô£ô Autostart rimosso${NC}"    fi        
echo -e "\n${GREEN}Ô£à CheckMK Agent disinstallato${NC}"}
# =====================================================
# Funzione: Disinstalla FRPC
# =====================================================uninstall_frpc() {    
echo -e "\n${RED}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"    
echo -e "${RED}Ôòæ           DISINSTALLAZIONE FRPC CLIENT                    Ôòæ${NC}"    
echo -e "${RED}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"        
echo -e "\n${YELLOW}­ƒùæ´©Å  Rimozione FRPC...${NC}\n"        
# Stop servizio    if [ -f "$FRPC_DIR/stop_frpc.sh" ]; then        "$FRPC_DIR/stop_frpc.sh"    fi        killall frpc 2>/dev/null || true        
# Rimuovi directory    if [ -d "$FRPC_DIR" ]; then        rm -rf "$FRPC_DIR"        
echo -e "${GREEN}Ô£ô Directory FRPC rimossa${NC}"    fi        
# Rimuovi symlink    if [ -L /usr/local/bin/frpc ]; then        rm -f /usr/local/bin/frpc        
echo -e "${GREEN}Ô£ô Symlink rimosso${NC}"    fi        
# Rimuovi da autorun    if [ -f "$QNAP_AUTORUN" ]; then        sed -i '/
# FRPC Client autostart/,/
# End FRPC Client/d' "$QNAP_AUTORUN"        
echo -e "${GREEN}Ô£ô Autostart rimosso${NC}"    fi        
echo -e "\n${GREEN}Ô£à FRPC disinstallato${NC}"}
# =====================================================
# Gestione parametri
# =====================================================case "$1" in    --help|-h)        show_usage        ;;    --uninstall-frpc)        
MODE="uninstall-frpc"        ;;    --uninstall-agent)        
MODE="uninstall-agent"        ;;    --uninstall)        
MODE="uninstall-all"        ;;    "")        
MODE="install"        ;;    *)        
echo -e "${RED}Ô£ù Parametro non vali
do: $1${NC}"        show_usage        ;;esac
# =====================================================
# Verifica permessi root
# =====================================================if [ "$(id -u)" -ne 0 ]; then    
echo -e "${RED}Ô£ù Questo script deve essere eseguito come root o admin${NC}"    exit 1fi
# =====================================================
# Esegui modalit├á richiesta
# =====================================================if [ "$MODE" = "uninstall-frpc" ]; then    uninstall_frpc    exit 0elif [ "$MODE" = "uninstall-agent" ]; then    uninstall_agent    exit 0elif [ "$MODE" = "uninstall-all" ]; then    
echo -e "${RED}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"    
echo -e "${RED}Ôòæ        DISINSTALLAZIONE COMPLETA (Agent + FRPC)          Ôòæ${NC}"    
echo -e "${RED}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"    
echo ""    
echo -ne "${YELLOW}Sei sicuro di voler rimuovere tutto? ${NC}[s/N]: "    read -r CONFIRM    if [[ "$CONFIRM" =~ ^[sS]$ ]]; then        uninstall_frpc        
echo ""        uninstall_agent        
echo -e "\n${GREEN}­ƒÄë Disinstallazione completa terminata!${NC}\n"    else        
echo -e "${CYAN}ÔØî Operazione annullata${NC}"    fi    exit 0fi
# =====================================================
# Modalit├á installazione
# =====================================================show_banner
# Verifica sistemacheck_qnap_system
# Installa dipendenzeinstall_dependencies
# Installa CheckMK Agentdownload_checkmk_agentinstall_checkmk_agentconfigure_agent_service
# Chiedi se installare anche FRPC (dopo l'agent)
echo -e "\n${CYAN}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"
echo -e "${CYAN}Ôòæ  CheckMK Agent installato con successo!                   Ôòæ${NC}"
echo -e "${CYAN}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"
echo -e "\n${CYAN}Vuoi installare anche FRPC Client per il tunneling remoto?${NC}"
echo -e "${YELLOW}FRPC permette di accedere all'agent attraverso un tunnel FRP${NC}"
echo -ne "\n${YELLOW}Installare FRPC? ${NC}[s/N]: "read -r 
INSTALL_FRPC_INPUTINSTALL_FRPC="no"
if [[ "$INSTALL_FRPC_INPUT" =~ ^[sS]$ ]]; then    
INSTALL_FRPC="yes"    
# Installa e configura FRPC    install_frpc    configure_frpc
fi
# Configura autostartconfigure_autostart
# Avvia servizistart_services
# Test finalerun_tests
# Mostra riepilogoshow_summaryexit 0

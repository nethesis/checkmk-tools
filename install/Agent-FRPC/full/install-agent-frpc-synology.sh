#!/bin/bash
# =====================================================
# Script Installazione CheckMK Agent + FRPC per Synology NAS
# - Installazione ottimizzata per Synology DSM 6.x/7.x
# - Gestione agent CheckMK in modalit├á plain (TCP 6556)
# - Configurazione FRPC client per tunnel
# - Supporto autostart tramite systemd/upstart
# - Compatibile con Synology DSM 6.x e 7.x
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
# Directory Synology specifiche
SYNOLOGY_VOLUME="/volume1"
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
echo -e "${CYAN}Ôòæ  Installazione CheckMK Agent + FRPC per Synology NAS     Ôòæ${NC}"    
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
echo -e "  ÔÇó Synology DSM 6.x/7.x"    
echo -e "  ÔÇó Accesso SSH attivo"    
echo -e "  ÔÇó Utente admin o root"    
echo -e "  ÔÇó Almeno 100MB di spazio disco disponibile"    
echo ""    exit 0}
# =====================================================
# Funzione: Verifica sistema Synology
# =====================================================check_synology_system() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ VERIFICA SISTEMA SYNOLOGY ÔòÉÔòÉÔòÉ${NC}"        
# Rileva tipo di NAS    
NAS_TYPE="generic"        if [ -f /etc/synoinfo.conf ]; then        
NAS_TYPE="synology"        
DSM_VERSION=$(grep -oP 'majorversion="\K[^"]+' /etc/synoinfo.conf 2>/dev/null || 
echo "Unknown")        
DSM_MINOR=$(grep -oP 'minorversion="\K[^"]+' /etc/synoinfo.conf 2>/dev/null || 
echo "0")        
UNIQUE_KEY=$(grep -oP 'unique="\K[^"]+' /etc/synoinfo.conf 2>/dev/null || 
echo "Unknown")                
echo -e "${GREEN}Ô£ô Synology NAS rilevato${NC}"        
echo -e "   DSM Version: ${CYAN}${DSM_VERSION}.${DSM_MINOR}${NC}"        
echo -e "   Unique Key: ${CYAN}${UNIQUE_KEY}${NC}"    elif [ -f /etc.defaults/VERSION ]; then        
NAS_TYPE="synology"        
echo -e "${GREEN}Ô£ô Synology NAS rilevato (alternativo)${NC}"        cat /etc.defaults/VERSION | head -3    else        
echo -e "${RED}Ô£ù Sistema Synology non rilevato${NC}"        
echo -e "${YELLOW}   Questo script ├¿ ottimizzato per Synology DSM${NC}"        
echo -n "   Continuare comunque? [s/N]: "        read -r CONFIRM        if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then            exit 1        fi    fi        
# Rileva architettura    
ARCH=$(uname -m)    
echo -e "   Architettura: ${CYAN}$ARCH${NC}"        
# Verifica se l'architettura ├¿ supportata    if [[ "$ARCH" != "x86_64" ]] && [[ "$ARCH" != "aarch64" ]]; then        
echo -e "${YELLOW}ÔÜá´©Å  Architettura $ARCH potrebbe non essere completamente supportata${NC}"        
echo -e "${YELLOW}   Lo script continuer├á ma potrebbero esserci problemi${NC}"        
echo -n "   Continuare comunque? [s/N]: "        read -r CONFIRM        if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then            exit 1        fi    fi        
# Adatta URL FRP in base all'architettura    if [[ "$ARCH" == "aarch64" ]]; then        
FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_arm64.tar.gz"        
echo -e "   ${CYAN}Usan
do FRP per ARM64${NC}"    fi        
# Verifica spazio disco    
AVAILABLE_SPACE="0"    if [ -d "$SYNOLOGY_VOLUME" ]; then        
AVAILABLE_SPACE=$(df -BM "$SYNOLOGY_VOLUME" 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/M//' || 
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
echo -e "${YELLOW}ÔÜá´©Å  wget non trovato, tentativo installazione...${NC}"        if command -v ipkg >/dev/null 2>&1; then            ipkg update && ipkg install wget        elif command -v opkg >/dev/null 2>&1; then            opkg update && opkg install wget        else            
echo -e "${RED}Ô£ù Impossibile installare wget${NC}"            
echo -e "${YELLOW}   Installa manualmente ipkg/Entware prima di continuare${NC}"            exit 1        fi    else        
echo -e "${GREEN}Ô£ô wget disponibile${NC}"    fi        
# Verifica tar    if ! command -v tar >/dev/null 2>&1; then        
echo -e "${RED}Ô£ù tar non disponibile${NC}"        exit 1    else        
echo -e "${GREEN}Ô£ô tar disponibile${NC}"    fi        
# Verifica socat (necessario per agent plain)    if ! command -v socat >/dev/null 2>&1; then        
echo -e "${YELLOW}ÔÜá´©Å  socat non trovato, tentativo installazione...${NC}"                
SOCAT_INSTALLED=false                if command -v ipkg >/dev/null 2>&1; then            
echo -e "${CYAN}   Usan
do ipkg (Synology)...${NC}"            ipkg update 2>&1 | grep -v "Signature check"            if ipkg install socat 2>&1; then                
SOCAT_INSTALLED=true            fi        elif command -v opkg >/dev/null 2>&1; then            
echo -e "${CYAN}   Usan
do opkg (Entware)...${NC}"            opkg update 2>&1 | grep -v "Signature check"            if opkg install socat 2>&1; then                
SOCAT_INSTALLED=true            fi        else            
echo -e "${RED}Ô£ù Package manager non trovato${NC}"            
echo -e "${YELLOW}   Installa Entware per aggiungere pacchetti aggiuntivi${NC}"            
echo -e "${YELLOW}   Visita: https://github.com/Entware/Entware${NC}"        fi                
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
# Funzione: Configura agent standalone (senza socat)
# =====================================================configure_agent_standalone() {    
echo -e "${CYAN}Configurazione standalone (senza socat)...${NC}"        
# Crea wrapper daemon in Python/Bash    cat > "$AGENT_DIR/agent_daemon.sh" <<'DAEMON_EOF'
#!/bin/bash
# CheckMK Agent Daemon - Plain TCP Server
# Ottimizzato per Synology con Python 2.7+ compatibilit├á
AGENT_BIN="/opt/checkmk/bin/check_mk_agent"
PORT=6556
LOG_FILE="/opt/checkmk/log/agent.log"
PID_FILE="/var/run/checkmk_agent.pid"
# Funzione per logginglog_msg() {    
echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"}
# Controlla se gi├á in esecuzione
if [ -f "$PID_FILE" ]; then    
OLD_PID=$(cat "$PID_FILE")    if ps -p "$OLD_PID" > /dev/null 2>&1; then        log_msg "Agent gi├á in esecuzione (PID: $OLD_PID)"        
echo "Agent gi├á in esecuzione (PID: $OLD_PID)"        exit 0    else        rm -f "$PID_FILE"    fi
fi
# Verifica se la porta ├¿ gi├á in uso
if netstat -tuln 2>/dev/null | grep -q ":$PORT "; then    log_msg "ERRORE: Porta $PORT gi├á in uso"    
echo "ERRORE: Porta $PORT gi├á in uso"    exit 1filog_msg "Avvio CheckMK Agent daemon sulla porta $PORT"
# Prova con Python (preferito)if command -v python3 >/dev/null 2>&1; then    
PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then    
PYTHON_CMD="python"
else    
PYTHON_CMD=""fi
if [ -n "$PYTHON_CMD" ]; then    log_msg "Usan
do Python daemon"        
# Daemon Python    cat > /tmp/checkmk_daemon_$$.py <<'PYEOF'
#!/usr/bin/env python
# -*- coding: utf-8 -*-import socketimport subprocessimport sysimport osimport signalimport timePORT = 6556AGENT_BIN = "/opt/checkmk/bin/check_mk_agent"LOG_FILE = "/opt/checkmk/log/agent.log"PID_FILE = "/var/run/checkmk_agent.pid"def log(msg):    with open(LOG_FILE, 'a') as f:        f.write("{}: {}\n".format(time.strftime("%Y-%m-%d %H:%M:%S"), msg))def cleanup(signum=None, frame=None):    log("Ricevuto segnale di terminazione, chiusura...")    try:        os.remove(PID_FILE)    except:        pass    sys.exit(0)signal.signal(signal.SIGTERM, cleanup)signal.signal(signal.SIGINT, cleanup)
# Salva PIDwith open(PID_FILE, 'w') as f:    f.write(str(os.getpid()))log("Daemon avviato su porta {}".format(PORT))
# Crea socketserver = socket.socket(socket.AF_INET, socket.SOCK_STREAM)server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)server.bind(('0.0.0.0', PORT))server.listen(5)log("In ascolto sulla porta {}".format(PORT))while True:    try:        client, addr = server.accept()        log("Connessione da {}".format(addr[0]))                try:            
# Esegui agent e invia output            output = subprocess.check_output([AGENT_BIN], stderr=subprocess.STDOUT)            client.sendall(output)        except Exception as e:            log("Errore esecuzione agent: {}".format(str(e)))        finally:            client.close()                except KeyboardInterrupt:        break    except Exception as e:        log("Errore: {}".format(str(e)))        time.sleep(1)cleanup()PYEOF        chmod +x /tmp/checkmk_daemon_$$.py        
# Start daemon in background (senza nohup per compatibilit├á Synology)    $PYTHON_CMD /tmp/checkmk_daemon_$$.py >> "$LOG_FILE" 2>&1 &    
DAEMON_PID=$!    
echo $DAEMON_PID > "$PID_FILE"        sleep 2        if ps -p $DAEMON_PID > /dev/null 2>&1; then        log_msg "Daemon avviato con successo (PID: $DAEMON_PID)"        
echo "Daemon avviato con successo (PID: $DAEMON_PID)"    else        log_msg "ERRORE: Impossibile avviare il daemon"        
echo "ERRORE: Impossibile avviare il daemon"        rm -f "$PID_FILE"        exit 1    fi
else    log_msg "ERRORE: Python non disponibile e socat non installato"    
echo "ERRORE: Python non disponibile e socat non installato"    exit 1fiDAEMON_EOF        chmod +x "$AGENT_DIR/agent_daemon.sh"        
# Crea script di avvio che usa il daemon    cat > "$AGENT_DIR/start_agent.sh" <<'EOF'
#!/bin/bash/opt/checkmk/agent_daemon.shEOF        chmod +x "$AGENT_DIR/start_agent.sh"        
# Crea script di stop    cat > "$AGENT_DIR/stop_agent.sh" <<'EOF'
#!/bin/bash
LOG_FILE="/opt/checkmk/log/agent.log"
PID_FILE="/var/run/checkmk_agent.pid"
echo "$(date): Stopping CheckMK Agent" >> "$LOG_FILE"
if [ -f "$PID_FILE" ]; then    
PID=$(cat "$PID_FILE")    if ps -p "$PID" > /dev/null 2>&1; then        kill "$PID" 2>/dev/null        rm -f "$PID_FILE"        
echo "CheckMK Agent stopped (PID: $PID)"    else        
echo "Agent non in esecuzione"        rm -f "$PID_FILE"    fi
else    
# Fallback: kill tutti i processi    killall -9 python 2>/dev/null | grep checkmk    
echo "Agent stopped (fallback)"fiEOF        chmod +x "$AGENT_DIR/stop_agent.sh"        
echo -e "${GREEN}Ô£ô Script di controllo creati (standalone mode)${NC}"}
# =====================================================
# Funzione: Configura autostart per Synology
# =====================================================setup_autostart() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ CONFIGURAZIONE AUTOSTART ÔòÉÔòÉÔòÉ${NC}"        
# Crea script di autostart per DSM    
AUTOSTART_SCRIPT="/usr/local/etc/rc.d/checkmk.sh"        cat > "$AUTOSTART_SCRIPT" <<'EOF'
#!/bin/sh
# CheckMK Agent autostart for Synology DSMcase "$1" in    start)        /opt/checkmk/start_agent.sh        ;;    stop)        /opt/checkmk/stop_agent.sh        ;;    restart)        /opt/checkmk/stop_agent.sh        sleep 2        /opt/checkmk/start_agent.sh        ;;    *)        
echo "Usage: $0 {start|stop|restart}"        exit 1        ;;esacexit 0EOF        chmod +x "$AUTOSTART_SCRIPT"        
echo -e "${GREEN}Ô£ô Autostart configurato${NC}"    
echo -e "   Script: ${CYAN}$AUTOSTART_SCRIPT${NC}"        
# Avvia il servizio    
echo -e "\n${CYAN}Avvio servizio CheckMK Agent...${NC}"    "$AUTOSTART_SCRIPT" start        sleep 3        
# Verifica che sia attivo    if is_process_running "check_mk"; then        
echo -e "${GREEN}Ô£ô Servizio avviato con successo${NC}"    else        
echo -e "${YELLOW}ÔÜá´©Å  Servizio potrebbe non essere attivo${NC}"        
echo -e "   Verifica i log: ${CYAN}$AGENT_DIR/log/agent.log${NC}"    fi}
# =====================================================
# Funzione: Scarica FRPC
# =====================================================download_frpc() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ DOWNLOAD FRPC CLIENT ÔòÉÔòÉÔòÉ${NC}"        
echo -e "${YELLOW}­ƒôª Download FRPC v${FRP_VERSION}...${NC}"    
echo -e "   URL: ${CYAN}$FRP_URL${NC}"        cd /tmp || exit 1    rm -f frp_*.tar.gz 2>/dev/null        if wget -q --show-progress "$FRP_URL" -O frp.tar.gz 2>&1; then        
echo -e "${GREEN}Ô£ô Download completato${NC}"    else        
echo -e "${RED}Ô£ù Errore durante il download di FRPC${NC}"        exit 1    fi        
# Estrai archivio    
echo -e "${YELLOW}­ƒôª Estrazione archivio...${NC}"    tar -xzf frp.tar.gz        
# Trova directory estratta    
FRP_DIR_NAME=$(find . -maxdepth 1 -type d -name "frp_*" | head -1)        if [ -z "$FRP_DIR_NAME" ] || [ ! -f "$FRP_DIR_NAME/frpc" ]; then        
echo -e "${RED}Ô£ù Errore nell'estrazione di FRPC${NC}"        exit 1    fi        
echo -e "${GREEN}Ô£ô FRPC estratto con successo${NC}"}
# =====================================================
# Funzione: Installa FRPC
# =====================================================install_frpc() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ INSTALLAZIONE FRPC ÔòÉÔòÉÔòÉ${NC}"        
# Crea directory    mkdir -p "$FRPC_DIR"    mkdir -p "$FRPC_DIR/bin"    mkdir -p "$FRPC_DIR/conf"    mkdir -p "$FRPC_DIR/log"        
# Copia binario    
echo -e "${YELLOW}­ƒôª Installazione FRPC...${NC}"    
FRP_DIR_NAME=$(find /tmp -maxdepth 1 -type d -name "frp_*" | head -1)    cp "$FRP_DIR_NAME/frpc" "$FRPC_DIR/bin/"    chmod +x "$FRPC_DIR/bin/frpc"        
# Crea symlink    ln -sf "$FRPC_DIR/bin/frpc" /usr/bin/frpc        
echo -e "${GREEN}Ô£ô FRPC installato in $FRPC_DIR${NC}"        
# Test FRPC    
echo -e "\n${CYAN}­ƒôè Test FRPC:${NC}"    if "$FRPC_DIR/bin/frpc" --version; then        
echo -e "${GREEN}Ô£ô FRPC funzionante${NC}"    else        
echo -e "${RED}Ô£ù Errore nel test di FRPC${NC}"        exit 1    fi}
# =====================================================
# Funzione: Configura FRPC
# =====================================================configure_frpc() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ CONFIGURAZIONE FRPC ÔòÉÔòÉÔòÉ${NC}"        
# Chiedi parametri di configurazione    
echo -e "${CYAN}Inserisci i parametri di configurazione FRPC:${NC}"    
echo ""        
# Server FRP    
echo -n "Server FRP [frp.nethlab.it]: "    read -r FRP_SERVER    
FRP_SERVER=${FRP_SERVER:-frp.nethlab.it}        
# Porta server    
echo -n "Porta server FRP [7000]: "    read -r FRP_SERVER_PORT    
FRP_SERVER_PORT=${FRP_SERVER_PORT:-7000}        
# Token autenticazione    
echo -n "Token autenticazione: "    read -r FRP_TOKEN    if [ -z "$FRP_TOKEN" ]; then        
echo -e "${RED}Ô£ù Token obbligatorio${NC}"        exit 1    fi        
# Nome host/client    
CURRENT_HOSTNAME=$(hostname 2>/dev/null || 
echo "synology-host")    
echo -n "Nome client [$CURRENT_HOSTNAME]: "    read -r CLIENT_NAME    
CLIENT_NAME=${CLIENT_NAME:-$CURRENT_HOSTNAME}        
# Porta remota    
echo -n "Porta remota per il tunnel [auto]: "    read -r REMOTE_PORT    
REMOTE_PORT=${REMOTE_PORT:-0}        
# Crea configurazione TOML    cat > "$FRPC_DIR/conf/frpc.toml" <<EOF
# FRPC Configuration for Synology NAS
# Generated: $(date)
# =====================================================
# Server Configuration
# =====================================================serverAddr = "$FRP_SERVER"serverPort = $FRP_SERVER_PORTauth.method = "token"auth.token = "$FRP_TOKEN"
# =====================================================
# Client Configuration
# =====================================================user = "$CLIENT_NAME"loginFailExit = false
# Logginglog.to = "$FRPC_DIR/log/frpc.log"log.level = "info"log.maxDays = 7
# =====================================================
# Proxies - CheckMK Agent
# =====================================================[[proxies]]name = "${CLIENT_NAME}-checkmk"type = "tcp"localIP = "127.0.0.1"localPort = 6556remotePort = $REMOTE_PORTEOF        
echo -e "${GREEN}Ô£ô Configurazione FRPC creata${NC}"    
echo -e "   Config: ${CYAN}$FRPC_DIR/conf/frpc.toml${NC}"        
# Mostra riepilogo    
echo -e "\n${CYAN}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"    
echo -e "${CYAN}Ôòæ  Riepilogo Configurazione FRPC                            Ôòæ${NC}"    
echo -e "${CYAN}ÔòáÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòú${NC}"    
echo -e "${CYAN}Ôòæ${NC}  Server:        ${GREEN}$FRP_SERVER:$FRP_SERVER_PORT${NC}"    
echo -e "${CYAN}Ôòæ${NC}  Client:        ${GREEN}$CLIENT_NAME${NC}"    
echo -e "${CYAN}Ôòæ${NC}  Tunnel:        ${GREEN}${CLIENT_NAME}-checkmk${NC}"    
echo -e "${CYAN}Ôòæ${NC}  Porta locale:  ${GREEN}6556${NC}"    
echo -e "${CYAN}Ôòæ${NC}  Porta remota:  ${GREEN}$REMOTE_PORT${NC} ${YELLOW}(0 = assegnata automaticamente)${NC}"    
echo -e "${CYAN}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"}
# =====================================================
# Funzione: Crea script di gestione FRPC
# =====================================================create_frpc_scripts() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ CREAZIONE SCRIPT GESTIONE FRPC ÔòÉÔòÉÔòÉ${NC}"        
# Script di avvio    cat > "$FRPC_DIR/start_frpc.sh" <<'EOF'
#!/bin/bash
# Start FRPC Client
FRPC_BIN="/opt/frpc/bin/frpc"
FRPC_CONF="/opt/frpc/conf/frpc.toml"
LOG_FILE="/opt/frpc/log/startup.log"
PID_FILE="/var/run/frpc.pid"
# Controlla se gi├á in esecuzione
if [ -f "$PID_FILE" ]; then    
OLD_PID=$(cat "$PID_FILE")    if ps -p "$OLD_PID" > /dev/null 2>&1; then        
echo "FRPC gi├á in esecuzione (PID: $OLD_PID)"        exit 0    else        rm -f "$PID_FILE"    fi
fi
echo "$(date): Starting FRPC" >> "$LOG_FILE"
# Start FRPC (senza nohup per compatibilit├á Synology)$FRPC_BIN -c "$FRPC_CONF" >> "$LOG_FILE" 2>&1 &
FRPC_PID=$!
echo $FRPC_PID > "$PID_FILE"sleep 2
if ps -p $FRPC_PID > /dev/null 2>&1; then    
echo "FRPC started successfully (PID: $FRPC_PID)"else    
echo "Failed to start FRPC"    rm -f "$PID_FILE"    exit 1fiEOF        chmod +x "$FRPC_DIR/start_frpc.sh"        
# Script di stop    cat > "$FRPC_DIR/stop_frpc.sh" <<'EOF'
#!/bin/bash
# Stop FRPC Client
LOG_FILE="/opt/frpc/log/startup.log"
PID_FILE="/var/run/frpc.pid"
echo "$(date): Stopping FRPC" >> "$LOG_FILE"
if [ -f "$PID_FILE" ]; then    
PID=$(cat "$PID_FILE")    if ps -p "$PID" > /dev/null 2>&1; then        kill "$PID" 2>/dev/null        rm -f "$PID_FILE"        
echo "FRPC stopped (PID: $PID)"    else        
echo "FRPC not running"        rm -f "$PID_FILE"    fi
else    
# Fallback    killall frpc 2>/dev/null    
echo "FRPC stopped (fallback)"fiEOF        chmod +x "$FRPC_DIR/stop_frpc.sh"        
# Script di restart    cat > "$FRPC_DIR/restart_frpc.sh" <<'EOF'
#!/bin/bash
# Restart FRPC Client/opt/frpc/stop_frpc.shsleep 2/opt/frpc/start_frpc.shEOF        chmod +x "$FRPC_DIR/restart_frpc.sh"        
echo -e "${GREEN}Ô£ô Script di gestione FRPC creati${NC}"}
# =====================================================
# Funzione: Configura autostart FRPC
# =====================================================setup_frpc_autostart() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ CONFIGURAZIONE AUTOSTART FRPC ÔòÉÔòÉÔòÉ${NC}"        
# Crea script di autostart per DSM    
AUTOSTART_SCRIPT="/usr/local/etc/rc.d/frpc.sh"        cat > "$AUTOSTART_SCRIPT" <<'EOF'
#!/bin/sh
# FRPC Client autostart for Synology DSMcase "$1" in    start)        /opt/frpc/start_frpc.sh        ;;    stop)        /opt/frpc/stop_frpc.sh        ;;    restart)        /opt/frpc/restart_frpc.sh        ;;    *)        
echo "Usage: $0 {start|stop|restart}"        exit 1        ;;esacexit 0EOF        chmod +x "$AUTOSTART_SCRIPT"        
echo -e "${GREEN}Ô£ô Autostart FRPC configurato${NC}"    
echo -e "   Script: ${CYAN}$AUTOSTART_SCRIPT${NC}"        
# Avvia il servizio    
echo -e "\n${CYAN}Avvio servizio FRPC...${NC}"    "$AUTOSTART_SCRIPT" start        sleep 3        
# Verifica che sia attivo    if is_process_running "frpc"; then        
echo -e "${GREEN}Ô£ô Servizio FRPC avviato con successo${NC}"        
echo -e "\n${CYAN}Controlla i log per verificare la connessione:${NC}"        
echo -e "   ${CYAN}tail -f $FRPC_DIR/log/frpc.log${NC}"    else        
echo -e "${YELLOW}ÔÜá´©Å  Servizio FRPC potrebbe non essere attivo${NC}"        
echo -e "   Verifica i log: ${CYAN}$FRPC_DIR/log/startup.log${NC}"    fi}
# =====================================================
# Funzione: Uninstall CheckMK Agent
# =====================================================uninstall_agent() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ RIMOZIONE CHECKMK AGENT ÔòÉÔòÉÔòÉ${NC}"        
# Stop servizio    if [ -f "$AGENT_DIR/stop_agent.sh" ]; then        
echo -e "${YELLOW}Arresto servizio...${NC}"        "$AGENT_DIR/stop_agent.sh"    fi        
# Rimuovi autostart    if [ -f "/usr/local/etc/rc.d/checkmk.sh" ]; then        
echo -e "${YELLOW}Rimozione autostart...${NC}"        rm -f "/usr/local/etc/rc.d/checkmk.sh"    fi        
# Rimuovi directory    if [ -d "$AGENT_DIR" ]; then        
echo -e "${YELLOW}Rimozione directory...${NC}"        rm -rf "$AGENT_DIR"    fi        
# Rimuovi symlink    rm -f /usr/bin/check_mk_agent        
echo -e "${GREEN}Ô£ô CheckMK Agent rimosso${NC}"}
# =====================================================
# Funzione: Uninstall FRPC
# =====================================================uninstall_frpc() {    
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉ RIMOZIONE FRPC ÔòÉÔòÉÔòÉ${NC}"        
# Stop servizio    if [ -f "$FRPC_DIR/stop_frpc.sh" ]; then        
echo -e "${YELLOW}Arresto servizio...${NC}"        "$FRPC_DIR/stop_frpc.sh"    fi        
# Rimuovi autostart    if [ -f "/usr/local/etc/rc.d/frpc.sh" ]; then        
echo -e "${YELLOW}Rimozione autostart...${NC}"        rm -f "/usr/local/etc/rc.d/frpc.sh"    fi        
# Rimuovi directory    if [ -d "$FRPC_DIR" ]; then        
echo -e "${YELLOW}Rimozione directory...${NC}"        rm -rf "$FRPC_DIR"    fi        
# Rimuovi symlink    rm -f /usr/bin/frpc        
echo -e "${GREEN}Ô£ô FRPC rimosso${NC}"}
# =====================================================
# Funzione: Mostra riepilogo finale
# =====================================================show_summary() {    
echo -e "\n${GREEN}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"    
echo -e "${GREEN}Ôòæ           INSTALLAZIONE COMPLETATA CON SUCCESSO!          Ôòæ${NC}"    
echo -e "${GREEN}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"    
echo ""    
echo -e "${CYAN}­ƒôé Directory installazione:${NC}"    
echo -e "   CheckMK Agent: ${GREEN}$AGENT_DIR${NC}"    if [ -d "$FRPC_DIR" ]; then        
echo -e "   FRPC Client:   ${GREEN}$FRPC_DIR${NC}"    fi    
echo ""    
echo -e "${CYAN}­ƒÄ« Comandi utili:${NC}"    
echo -e "   ${YELLOW}
# Gestione CheckMK Agent${NC}"    
echo -e "   ${GREEN}$AGENT_DIR/start_agent.sh${NC}      
# Avvia agent"    
echo -e "   ${GREEN}$AGENT_DIR/stop_agent.sh${NC}       
# Ferma agent"    
echo -e "   ${GREEN}check_mk_agent${NC}                 
# Test manuale agent"    
echo -e "   ${GREEN}tail -f $AGENT_DIR/log/agent.log${NC}  
# Log agent"    
echo ""    if [ -d "$FRPC_DIR" ]; then        
echo -e "   ${YELLOW}
# Gestione FRPC${NC}"        
echo -e "   ${GREEN}$FRPC_DIR/start_frpc.sh${NC}       
# Avvia FRPC"        
echo -e "   ${GREEN}$FRPC_DIR/stop_frpc.sh${NC}        
# Ferma FRPC"        
echo -e "   ${GREEN}$FRPC_DIR/restart_frpc.sh${NC}     
# Riavvia FRPC"        
echo -e "   ${GREEN}tail -f $FRPC_DIR/log/frpc.log${NC}    
# Log FRPC"        
echo ""    fi    
echo -e "${CYAN}­ƒöº Test connessione:${NC}"    
echo -e "   ${GREEN}nc -zv localhost 6556${NC}           
# Test locale porta agent"    if [ -d "$FRPC_DIR" ]; then        
echo -e "   ${GREEN}ps aux | grep frpc${NC}             
# Verifica processo FRPC"    fi    
echo ""    
echo -e "${CYAN}­ƒôØ Note:${NC}"    
echo -e "   ÔÇó I servizi si avviano automaticamente al boot"    
echo -e "   ÔÇó Configura firewall per permettere connessioni sulla porta 6556"    if [ -d "$FRPC_DIR" ]; then        
echo -e "   ÔÇó Monitora i log FRPC per confermare la connessione al server"    fi    
echo ""}
# =====================================================
# MAIN - Gestione parametri
# =====================================================
# Verifica se root
if [ "$EUID" -ne 0 ] && [ "$(id -u)" -ne 0 ]; then    
echo -e "${RED}Ô£ù Questo script deve essere eseguito come root${NC}"    
echo -e "${YELLOW}   Usa: su
do $0${NC}"    exit 1fi
# Parsing parametricase "${1:-}" in    --help|-h)        show_usage        ;;    --uninstall)        show_banner        
echo -e "${RED}ÔÜá´©Å  ATTENZIONE: Rimozione completa di CheckMK Agent e FRPC${NC}"        
echo -n "Confermi? [s/N]: "        read -r CONFIRM        if [[ "$CONFIRM" =~ ^[sS]$ ]]; then            uninstall_agent            uninstall_frpc            
echo -e "\n${GREEN}Ô£ô Rimozione completata${NC}"        else            
echo -e "${CYAN}ÔØî Operazione annullata${NC}"        fi        exit 0        ;;    --uninstall-agent)        show_banner        
echo -e "${RED}ÔÜá´©Å  ATTENZIONE: Rimozione CheckMK Agent${NC}"        
echo -n "Confermi? [s/N]: "        read -r CONFIRM        if [[ "$CONFIRM" =~ ^[sS]$ ]]; then            uninstall_agent            
echo -e "\n${GREEN}Ô£ô Rimozione completata${NC}"        else            
echo -e "${CYAN}ÔØî Operazione annullata${NC}"        fi        exit 0        ;;    --uninstall-frpc)        show_banner        
echo -e "${RED}ÔÜá´©Å  ATTENZIONE: Rimozione FRPC${NC}"        
echo -n "Confermi? [s/N]: "        read -r CONFIRM        if [[ "$CONFIRM" =~ ^[sS]$ ]]; then            uninstall_frpc            
echo -e "\n${GREEN}Ô£ô Rimozione completata${NC}"        else            
echo -e "${CYAN}ÔØî Operazione annullata${NC}"        fi        exit 0        ;;esac
# =====================================================
# Modalit├á installazione
# =====================================================show_banner
# Verifica sistemacheck_synology_system
# Installa dipendenzeinstall_dependencies
# Installa CheckMK Agentdownload_checkmk_agentinstall_checkmk_agentconfigure_agent_servicesetup_autostart
# Chiedi se installare anche FRPC (dopo l'agent)
echo -e "\n${CYAN}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"
echo -e "${CYAN}Ôòæ  CheckMK Agent installato con successo!                   Ôòæ${NC}"
echo -e "${CYAN}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"
echo -e "\n${CYAN}Vuoi installare anche FRPC Client per il tunneling remoto?${NC}"
echo -e "${YELLOW}FRPC permette di esporre l'agent CheckMK attraverso un tunnel${NC}"
echo -e "${YELLOW}verso un server FRP, utile per monitoraggio di sistemi in NAT.${NC}"
echo ""
echo -n "Installare FRPC? [S/n]: "read -r INSTALL_FRPC
if [[ ! "$INSTALL_FRPC" =~ ^[nN]$ ]]; then    
# Installa FRPC    download_frpc    install_frpc    configure_frpc    create_frpc_scripts    setup_frpc_autostart
fi
# Mostra riepilogoshow_summary
echo -e "${GREEN}Ô£¿ Installazione terminata!${NC}"
echo ""

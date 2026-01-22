#!/bin/bash
# =====================================================
# Script Installazione CheckMK Agent + FRPC per QNAP NAS
# - Installazione ottimizzata per QNAP QTS/QuTS
# - Gestione agent CheckMK in modalità plain (TCP 6556)
# - Configurazione FRPC client per tunnel
# - Supporto autostart tramite autorun.sh
# - Compatibile con QNAP QTS 4.x e 5.x
# =====================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables
CHECKMK_VERSION="2.4.0p12"
FRP_VERSION="0.64.0"
QNAP_AUTORUN="/etc/config/autorun.sh"
AGENT_DIR="/opt/checkmk"
FRPC_DIR="/opt/frpc"
MODE="install"
USE_STANDALONE_MODE=false

# Process management functions
is_process_running() {
    local pattern="$1"
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -f "$pattern" >/dev/null 2>&1
    else
        ps aux 2>/dev/null | grep -v grep | grep -q "$pattern"
    fi
}

kill_process() {
  local pattern="$1"
  if command -v pkill >/dev/null 2>&1; then
    pkill -f "$pattern" 2>/dev/null
  else
    ps aux 2>/dev/null | grep -v grep | grep "$pattern" | while read -r line; do
      pid=$(echo "$line" | tr -s ' ' | cut -d' ' -f2)
      [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null
    done
  fi
}

show_banner() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  Installazione CheckMK Agent + FRPC per NAS       ║${NC}"
    echo -e "${CYAN}║  Version: 1.0 - $(date +%Y-%m-%d)                         ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_usage() {
    show_banner
    echo -e "${YELLOW}Uso:${NC}"
    echo -e "  $0                      ${GREEN}# Installazione interattiva${NC}"
    echo -e "  $0 --uninstall-frpc     ${RED}# Rimuove solo FRPC${NC}"
    echo -e "  $0 --uninstall-agent    ${RED}# Rimuove solo CheckMK Agent${NC}"
    echo -e "  $0 --uninstall          ${RED}# Rimuove tutto (FRPC + Agent)${NC}"
    echo -e "  $0 --help               ${CYAN}# Mostra questo messaggio${NC}"
    echo ""
    exit 0
}

check_qnap_system() {
    echo -e "\n${BLUE}═══ VERIFICA SISTEMA NAS ═══${NC}"
    
    # Detect NAS type
    NAS_TYPE="generic"
    
    if [ -f /etc/config/uLinux.conf ]; then
        NAS_TYPE="qnap"
        QTS_VERSION=$(grep -oP 'NAS_VERSION="\K[^"]+' /etc/config/uLinux.conf 2>/dev/null || echo "Unknown")
        echo -e "${GREEN}✔ QNAP NAS rilevato${NC}"
        echo -e "   QTS Version: ${CYAN}$QTS_VERSION${NC}"
    elif [ -f /etc/nethserver-release ]; then
        NAS_TYPE="nethesis"
        echo -e "${GREEN}✔ Nethesis NAS rilevato${NC}"
    elif [ -d /share/CACHEDEV1_DATA ] || [ -d /share/MD0_DATA ]; then
        NAS_TYPE="qnap-like"
        echo -e "${GREEN}✔ Sistema compatibile QNAP rilevato${NC}"
    else
        echo -e "${YELLOW}⚠  Sistema NAS generico rilevato${NC}"
    fi
    
    # Detect architecture
    ARCH=$(uname -m)
    echo -e "   Architettura: ${CYAN}$ARCH${NC}"
    
    if [[ "$ARCH" != "x86_64" ]] && [[ "$ARCH" != "aarch64" ]]; then
        echo -e "${YELLOW}⚠  Architettura $ARCH potrebbe non essere supportata${NC}"
        echo -n "   Continuare comunque? [s/N]: "
        read -r CONFIRM
        if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
            exit 1
        fi
    fi
    
    # Check disk space
    AVAILABLE_SPACE="0"
    if [ -d /share/CACHEDEV1_DATA ]; then
        AVAILABLE_SPACE=$(df -BM /share/CACHEDEV1_DATA 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/M//' || echo "0")
    elif [ -d /share/MD0_DATA ]; then
        AVAILABLE_SPACE=$(df -BM /share/MD0_DATA 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/M//' || echo "0")
    else
        AVAILABLE_SPACE=$(df -BM /opt 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/M//' || echo "1000")
    fi
    
    AVAILABLE_SPACE=$(echo "$AVAILABLE_SPACE" | grep -oE '[0-9]+' || echo "1000")
    
    if [ "$AVAILABLE_SPACE" -lt 100 ]; then
        echo -e "${YELLOW}⚠  Spazio disco limitato: ${AVAILABLE_SPACE}MB${NC}"
        echo -n "   Continuare? [s/N]: "
        read -r CONFIRM
        if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
            exit 1
        fi
    else
        echo -e "   Spazio disponibile: ${GREEN}${AVAILABLE_SPACE}MB${NC}"
    fi
}

install_dependencies() {
    echo -e "\n${BLUE}═══ VERIFICA DIPENDENZE ═══${NC}"
    
    # Check wget
    if ! command -v wget >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠  wget non trovato, tentativo installazione...${NC}"
        if command -v opkg >/dev/null 2>&1; then
            opkg update && opkg install wget
        elif command -v yum >/dev/null 2>&1; then
            yum install -y wget
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y wget
        else
            echo -e "${RED}✗ Impossibile installare wget${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✔ wget disponibile${NC}"
    fi
    
    # Check tar
    if ! command -v tar >/dev/null 2>&1; then
        echo -e "${RED}✗ tar non disponibile${NC}"
        exit 1
    else
        echo -e "${GREEN}✔ tar disponibile${NC}"
    fi
    
    # Check socat
    if ! command -v socat >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠  socat non trovato, tentativo installazione...${NC}"
        
        if command -v opkg >/dev/null 2>&1; then
            opkg update 2>&1 | grep -v "Signature check"
            opkg install socat 2>&1
        elif command -v yum >/dev/null 2>&1; then
            yum install -y socat
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y socat
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y socat
        fi
        
        if ! command -v socat >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠  socat non disponibile, uso metodo alternativo${NC}"
            USE_STANDALONE_MODE=true
        else
            echo -e "${GREEN}✔ socat installato${NC}"
        fi
    else
        echo -e "${GREEN}✔ socat disponibile${NC}"
    fi
}

download_checkmk_agent() {
    echo -e "\n${BLUE}═══ DOWNLOAD CHECKMK AGENT ═══${NC}"
    
    AGENT_URL="https://monitoring.nethlab.it/monitoring/check_mk/agents/check_mk_agent.linux"
    echo -e "${YELLOW}📥 Download agent v${CHECKMK_VERSION}...${NC}"
    
    cd /tmp || exit 1
    rm -f check_mk_agent.linux 2>/dev/null
    
    if wget -q --show-progress "$AGENT_URL" -O check_mk_agent.linux 2>&1; then
        echo -e "${GREEN}✔ Download completato${NC}"
    else
        echo -e "${RED}✗ Errore durante il download${NC}"
        exit 1
    fi
    
    if [ ! -f check_mk_agent.linux ] || [ ! -s check_mk_agent.linux ]; then
        echo -e "${RED}✗ File agent non valido${NC}"
        exit 1
    fi
    
    if ! head -n 1 check_mk_agent.linux | grep -q "^#!"; then
        echo -e "${RED}✗ File scaricato non è uno script valido${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✔ Agent scaricato e verificato${NC}"
}

install_checkmk_agent() {
    echo -e "\n${BLUE}═══ INSTALLAZIONE CHECKMK AGENT ═══${NC}"
    
    mkdir -p "$AGENT_DIR/bin" "$AGENT_DIR/log"
    
    echo -e "${YELLOW}📦 Installazione agent...${NC}"
    cp /tmp/check_mk_agent.linux "$AGENT_DIR/bin/check_mk_agent"
    chmod +x "$AGENT_DIR/bin/check_mk_agent"
    ln -sf "$AGENT_DIR/bin/check_mk_agent" /usr/bin/check_mk_agent
    
    echo -e "${GREEN}✔ Agent installato in $AGENT_DIR${NC}"
    
    echo -e "\n${CYAN}🔧 Test agent locale:${NC}"
    if "$AGENT_DIR/bin/check_mk_agent" | head -n 5; then
        echo -e "${GREEN}✔ Agent funzionante${NC}"
    else
        echo -e "${RED}✗ Errore nel test dell'agent${NC}"
        exit 1
    fi
}

configure_agent_service() {
    echo -e "\n${BLUE}═══ CONFIGURAZIONE SERVIZIO AGENT ═══${NC}"
    
    if [ "$USE_STANDALONE_MODE" = "true" ]; then
        configure_agent_standalone
    else
        configure_agent_socat
    fi
}

configure_agent_socat() {
    echo -e "${CYAN}Configurazione con socat...${NC}"
    
    cat > "$AGENT_DIR/start_agent.sh" <<'EOF'
#!/bin/bash
AGENT_BIN="/opt/checkmk/bin/check_mk_agent"
LOG_FILE="/opt/checkmk/log/agent.log"

killall socat 2>/dev/null
echo "$(date): Starting CheckMK Agent on port 6556" >> "$LOG_FILE"
socat TCP-LISTEN:6556,reuseaddr,fork EXEC:"$AGENT_BIN" 2>&1 | tee -a "$LOG_FILE" &
echo "CheckMK Agent started on port 6556"
EOF
    chmod +x "$AGENT_DIR/start_agent.sh"
    
    cat > "$AGENT_DIR/stop_agent.sh" <<'EOF'
#!/bin/bash
LOG_FILE="/opt/checkmk/log/agent.log"
echo "$(date): Stopping CheckMK Agent" >> "$LOG_FILE"
killall socat 2>/dev/null
echo "CheckMK Agent stopped"
EOF
    chmod +x "$AGENT_DIR/stop_agent.sh"
    
    echo -e "${GREEN}✔ Script di controllo creati (socat mode)${NC}"
}

configure_agent_standalone() {
    echo -e "${CYAN}Configurazione con script bash standalone...${NC}"
    
    cat > "$AGENT_DIR/agent_daemon.sh" <<'EOF'
#!/bin/bash
AGENT_BIN="/opt/checkmk/bin/check_mk_agent"
PORT=6556
LOG_FILE="/opt/checkmk/log/agent.log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE" 2>/dev/null || true
}

if command -v socat >/dev/null 2>&1; then
    log_msg "Starting with socat on port $PORT"
    while true; do
        socat TCP-LISTEN:$PORT,reuseaddr,fork EXEC:"$AGENT_BIN" 2>>"$LOG_FILE" || sleep 1
    done
elif command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then
    log_msg "Starting with Python on port $PORT"
    PYTHON_CMD=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
    $PYTHON_CMD -u << 'PYTHON_EOF'
import socket
import subprocess
import sys

PORT = 6556
AGENT_BIN = "/opt/checkmk/bin/check_mk_agent"

def handle_client(client_socket):
    try:
        proc = subprocess.Popen([AGENT_BIN], stdout=subprocess.PIPE)
        output, _ = proc.communicate()
        client_socket.sendall(output)
    except Exception as e:
        sys.stderr.write("Error: " + str(e) + "\n")
    finally:
        try:
            client_socket.close()
        except:
            pass

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', PORT))
    server.listen(5)
    print("CheckMK Agent listening on port " + str(PORT))
    sys.stdout.flush()
    
    while True:
        try:
            client, addr = server.accept()
            handle_client(client)
        except KeyboardInterrupt:
            break
        except Exception as e:
            sys.stderr.write("Error: " + str(e) + "\n")
    
    server.close()

if __name__ == "__main__":
    main()
PYTHON_EOF
else
    log_msg "ERROR: No suitable method found"
    exit 1
fi
EOF
    chmod +x "$AGENT_DIR/agent_daemon.sh"
    
    cat > "$AGENT_DIR/start_agent.sh" <<'EOF'
#!/bin/bash
DAEMON="/opt/checkmk/agent_daemon.sh"
LOG_FILE="/opt/checkmk/log/agent.log"
PID_FILE="/var/run/checkmk_agent.pid"

if command -v pkill >/dev/null 2>&1; then
    pkill -f "agent_daemon.sh" 2>/dev/null
else
    ps aux 2>/dev/null | grep -v grep | grep "agent_daemon.sh" | while read line; do
        pid=$(echo "$line" | tr -s ' ' | cut -d' ' -f2)
        [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null
    done
fi

echo "$(date): Starting Agent Daemon" >> "$LOG_FILE"
if command -v nohup >/dev/null 2>&1; then
    nohup "$DAEMON" >> "$LOG_FILE" 2>&1 &
else
    "$DAEMON" >> "$LOG_FILE" 2>&1 </dev/null &
fi
echo $! > "$PID_FILE"
echo "CheckMK Agent started on port 6556"
EOF
    chmod +x "$AGENT_DIR/start_agent.sh"
    
    cat > "$AGENT_DIR/stop_agent.sh" <<'EOF'
#!/bin/bash
LOG_FILE="/opt/checkmk/log/agent.log"
echo "$(date): Stopping Agent" >> "$LOG_FILE"

if command -v pkill >/dev/null 2>&1; then
    pkill -f "agent_daemon.sh" 2>/dev/null
else
    ps aux 2>/dev/null | grep -v grep | grep "agent_daemon.sh" | while read line; do
        pid=$(echo "$line" | tr -s ' ' | cut -d' ' -f2)
        [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null
    done
fi
rm -f "/var/run/checkmk_agent.pid"
echo "Agent stopped"
EOF
    chmod +x "$AGENT_DIR/stop_agent.sh"
    
    echo -e "${GREEN}✔ Configurazione standalone creata${NC}"
}

install_frpc() {
    echo -e "\n${BLUE}═══ INSTALLAZIONE FRPC CLIENT ═══${NC}"
    
    if [[ "$ARCH" == "aarch64" ]]; then
        FRP_ARCHIVE="frp_${FRP_VERSION}_linux_arm64.tar.gz"
        FRP_FOLDER="frp_${FRP_VERSION}_linux_arm64"
        FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/$FRP_ARCHIVE"
    else
        FRP_ARCHIVE="frp_${FRP_VERSION}_linux_amd64.tar.gz"
        FRP_FOLDER="frp_${FRP_VERSION}_linux_amd64"
        FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/$FRP_ARCHIVE"
    fi
    
    echo -e "${YELLOW}📥 Download FRPC v${FRP_VERSION}...${NC}"
    cd /tmp || exit 1
    rm -f "$FRP_ARCHIVE" 2>/dev/null
    rm -rf "$FRP_FOLDER" 2>/dev/null
    
    if wget -q --show-progress "$FRP_URL" -O "$FRP_ARCHIVE" 2>&1; then
        echo -e "${GREEN}✔ Download completato${NC}"
    else
        echo -e "${RED}✗ Errore download FRPC${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}📦 Estrazione...${NC}"
    tar -xzf "$FRP_ARCHIVE" || {
        echo -e "${RED}✗ Errore estrazione${NC}"
        exit 1
    }
    
    mkdir -p "$FRPC_DIR/bin" "$FRPC_DIR/conf" "$FRPC_DIR/log"
    cp "$FRP_FOLDER/frpc" "$FRPC_DIR/bin/frpc"
    chmod +x "$FRPC_DIR/bin/frpc"
    ln -sf "$FRPC_DIR/bin/frpc" /usr/local/bin/frpc
    rm -rf "$FRP_FOLDER" "$FRP_ARCHIVE"
    
    echo -e "${GREEN}✔ FRPC installato${NC}"
    "$FRPC_DIR/bin/frpc" --version
}

configure_frpc() {
    echo -e "\n${BLUE}═══ CONFIGURAZIONE FRPC ═══${NC}"
    
    CURRENT_HOSTNAME=$(hostname 2>/dev/null || echo "qnap-host")
    
    echo -ne "${CYAN}Nome host ${NC}[default: $CURRENT_HOSTNAME]: "
    read -r FRPC_HOSTNAME
    FRPC_HOSTNAME=${FRPC_HOSTNAME:-$CURRENT_HOSTNAME}
    
    echo -ne "${CYAN}Server FRP ${NC}[default: monitor.nethlab.it]: "
    read -r FRP_SERVER
    FRP_SERVER=${FRP_SERVER:-"monitor.nethlab.it"}
    
    echo -ne "${CYAN}Porta remota ${NC}[es: 20001]: "
    read -r REMOTE_PORT
    while [ -z "$REMOTE_PORT" ]; do
        echo -e "${RED}✗ Porta obbligatoria!${NC}"
        echo -ne "${CYAN}Porta remota: ${NC}"
        read -r REMOTE_PORT
    done
    
    echo -ne "${CYAN}Token ${NC}[default: conduit-reenact-talon-macarena-demotion-vaguely]: "
    read -r AUTH_TOKEN
    AUTH_TOKEN=${AUTH_TOKEN:-"conduit-reenact-talon-macarena-demotion-vaguely"}
    
    mkdir -p "$FRPC_DIR/conf"
    
    cat > "$FRPC_DIR/conf/frpc.toml" <<EOF
[common]
server_addr = "$FRP_SERVER"
server_port = 7000
auth.method = "token"
auth.token  = "$AUTH_TOKEN"
tls.enable = true
log.to = "$FRPC_DIR/log/frpc.log"
log.level = "info"

[$FRPC_HOSTNAME]
type        = "tcp"
local_ip    = "127.0.0.1"
local_port  = 6556
remote_port = $REMOTE_PORT
EOF
    
    echo -e "${GREEN}✔ Configurazione FRPC creata${NC}"
    
    cat > "$FRPC_DIR/start_frpc.sh" <<'EOF'
#!/bin/bash
FRPC_BIN="/opt/frpc/bin/frpc"
FRPC_CONF="/opt/frpc/conf/frpc.toml"
LOG_FILE="/opt/frpc/log/startup.log"
PID_FILE="/var/run/frpc.pid"

if command -v pkill >/dev/null 2>&1; then
    pkill -f "frpc -c" 2>/dev/null
else
    ps aux 2>/dev/null | grep -v grep | grep "frpc -c" | while read line; do
        pid=$(echo "$line" | tr -s ' ' | cut -d' ' -f2)
        [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null
    done
fi

echo "$(date): Starting FRPC" >> "$LOG_FILE"
if command -v nohup >/dev/null 2>&1; then
    nohup "$FRPC_BIN" -c "$FRPC_CONF" >> "$LOG_FILE" 2>&1 &
else
    "$FRPC_BIN" -c "$FRPC_CONF" >> "$LOG_FILE" 2>&1 </dev/null &
fi
echo $! > "$PID_FILE"
echo "FRPC started with PID $(cat $PID_FILE)"
EOF
    chmod +x "$FRPC_DIR/start_frpc.sh"
    
    cat > "$FRPC_DIR/stop_frpc.sh" <<'EOF'
#!/bin/bash
LOG_FILE="/opt/frpc/log/startup.log"
echo "$(date): Stopping FRPC" >> "$LOG_FILE"

if command -v pkill >/dev/null 2>&1; then
    pkill -f "frpc -c" 2>/dev/null
else
    ps aux 2>/dev/null | grep -v grep | grep "frpc -c" | while read line; do
        pid=$(echo "$line" | tr -s ' ' | cut -d' ' -f2)
        [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null
    done
fi
rm -f "/var/run/frpc.pid"
echo "FRPC stopped"
EOF
    chmod +x "$FRPC_DIR/stop_frpc.sh"
}

configure_autostart() {
    echo -e "\n${BLUE}═══ CONFIGURAZIONE AUTOSTART ═══${NC}"
    
    if [ -f "$QNAP_AUTORUN" ]; then
        cp "$QNAP_AUTORUN" "${QNAP_AUTORUN}.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${YELLOW}✔ Backup autorun.sh creato${NC}"
    fi
    
    if [ -f "$QNAP_AUTORUN" ]; then
        sed -i '/# CheckMK Agent autostart/,/# End CheckMK Agent/d' "$QNAP_AUTORUN"
        sed -i '/# FRPC Client autostart/,/# End FRPC Client/d' "$QNAP_AUTORUN"
    fi
    
    if [ ! -f "$QNAP_AUTORUN" ]; then
        echo '#!/bin/sh' > "$QNAP_AUTORUN"
        chmod +x "$QNAP_AUTORUN"
    fi
    
    cat >> "$QNAP_AUTORUN" <<EOF
# CheckMK Agent autostart
if [ -f "$AGENT_DIR/start_agent.sh" ]; then
    sleep 10
    $AGENT_DIR/start_agent.sh
fi
# End CheckMK Agent
EOF
    
    if [ "$INSTALL_FRPC" = "yes" ]; then
        cat >> "$QNAP_AUTORUN" <<EOF
# FRPC Client autostart
if [ -f "$FRPC_DIR/start_frpc.sh" ]; then
    sleep 15
    $FRPC_DIR/start_frpc.sh
fi
# End FRPC Client
EOF
    fi
    
    chmod +x "$QNAP_AUTORUN"
    echo -e "${GREEN}✔ Autostart configurato${NC}"
}

start_services() {
    echo -e "\n${BLUE}═══ AVVIO SERVIZI ═══${NC}"
    
    echo -e "${YELLOW}🚀 Avvio CheckMK Agent...${NC}"
    "$AGENT_DIR/start_agent.sh"
    sleep 2
    
    if [ "$USE_STANDALONE_MODE" = "true" ]; then
        if is_process_running "agent_daemon.sh"; then
            echo -e "${GREEN}✔ Agent attivo (standalone)${NC}"
        else
            echo -e "${YELLOW}⚠  Agent potrebbe non essere attivo${NC}"
        fi
    else
        if is_process_running "socat.*6556"; then
            echo -e "${GREEN}✔ Agent attivo (socat)${NC}"
        else
            echo -e "${YELLOW}⚠  Agent potrebbe non essere attivo${NC}"
        fi
    fi
    
    if [ "$INSTALL_FRPC" = "yes" ]; then
        echo -e "${YELLOW}🚀 Avvio FRPC...${NC}"
        "$FRPC_DIR/start_frpc.sh"
        sleep 3
        
        if is_process_running "frpc"; then
            echo -e "${GREEN}✔ FRPC attivo${NC}"
        else
            echo -e "${RED}✗ FRPC non avviato${NC}"
        fi
    fi
}

show_summary() {
    echo -e "\n${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           INSTALLAZIONE COMPLETATA                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📋 Informazioni:${NC}"
    echo -e "   • Agent directory: ${YELLOW}$AGENT_DIR${NC}"
    echo -e "   • Agent porta: ${YELLOW}6556${NC}"
    
    if [ "$INSTALL_FRPC" = "yes" ]; then
        echo -e "   • FRPC config: ${YELLOW}$FRPC_DIR/conf/frpc.toml${NC}"
        echo -e "   • FRPC porta remota: ${YELLOW}$REMOTE_PORT${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}📚 Comandi utili:${NC}"
    echo -e "   • Avvia agent:  ${YELLOW}$AGENT_DIR/start_agent.sh${NC}"
    echo -e "   • Ferma agent:  ${YELLOW}$AGENT_DIR/stop_agent.sh${NC}"
    
    if [ "$INSTALL_FRPC" = "yes" ]; then
        echo -e "   • Avvia FRPC:   ${YELLOW}$FRPC_DIR/start_frpc.sh${NC}"
        echo -e "   • Ferma FRPC:   ${YELLOW}$FRPC_DIR/stop_frpc.sh${NC}"
        echo -e "   • Log FRPC:     ${YELLOW}tail -f $FRPC_DIR/log/frpc.log${NC}"
    fi
    echo ""
}

uninstall_agent() {
    echo -e "\n${RED}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║     DISINSTALLAZIONE CHECKMK AGENT                 ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════╝${NC}"
    
    if [ -f "$AGENT_DIR/stop_agent.sh" ]; then
        "$AGENT_DIR/stop_agent.sh"
    fi
    
    killall socat 2>/dev/null || true
    
    if [ -d "$AGENT_DIR" ]; then
        rm -rf "$AGENT_DIR"
        echo -e "${GREEN}✔ Directory agent rimossa${NC}"
    fi
    
    if [ -L /usr/bin/check_mk_agent ]; then
        rm -f /usr/bin/check_mk_agent
        echo -e "${GREEN}✔ Symlink rimosso${NC}"
    fi
    
    if [ -f "$QNAP_AUTORUN" ]; then
        sed -i '/# CheckMK Agent autostart/,/# End CheckMK Agent/d' "$QNAP_AUTORUN"
        echo -e "${GREEN}✔ Autostart rimosso${NC}"
    fi
    
    echo -e "\n${GREEN}✓ CheckMK Agent disinstallato${NC}"
}

uninstall_frpc() {
    echo -e "\n${RED}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║        DISINSTALLAZIONE FRPC CLIENT                ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════╝${NC}"
    
    if [ -f "$FRPC_DIR/stop_frpc.sh" ]; then
        "$FRPC_DIR/stop_frpc.sh"
    fi
    
    killall frpc 2>/dev/null || true
    
    if [ -d "$FRPC_DIR" ]; then
        rm -rf "$FRPC_DIR"
        echo -e "${GREEN}✔ Directory FRPC rimossa${NC}"
    fi
    
    if [ -L /usr/local/bin/frpc ]; then
        rm -f /usr/local/bin/frpc
        echo -e "${GREEN}✔ Symlink rimosso${NC}"
    fi
    
    if [ -f "$QNAP_AUTORUN" ]; then
        sed -i '/# FRPC Client autostart/,/# End FRPC Client/d' "$QNAP_AUTORUN"
        echo -e "${GREEN}✔ Autostart rimosso${NC}"
    fi
    
    echo -e "\n${GREEN}✓ FRPC disinstallato${NC}"
}

# Parse arguments
case "$1" in
    --help|-h)
        show_usage
        ;;
    --uninstall-frpc)
        MODE="uninstall-frpc"
        ;;
    --uninstall-agent)
        MODE="uninstall-agent"
        ;;
    --uninstall)
        MODE="uninstall-all"
        ;;
    "")
        MODE="install"
        ;;
    *)
        echo -e "${RED}✗ Parametro non valido: $1${NC}"
        show_usage
        ;;
esac

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}✗ Questo script richiede privilegi root${NC}"
    exit 1
fi

# Execute mode
if [ "$MODE" = "uninstall-frpc" ]; then
    uninstall_frpc
    exit 0
elif [ "$MODE" = "uninstall-agent" ]; then
    uninstall_agent
    exit 0
elif [ "$MODE" = "uninstall-all" ]; then
    echo -ne "${YELLOW}Rimuovere tutto? ${NC}[s/N]: "
    read -r CONFIRM
    if [[ "$CONFIRM" =~ ^[sS]$ ]]; then
        uninstall_frpc
        echo ""
        uninstall_agent
        echo -e "\n${GREEN}🎉 Disinstallazione completa terminata${NC}"
    else
        echo -e "${CYAN}❌ Operazione annullata${NC}"
    fi
    exit 0
fi

# Install mode
show_banner
check_qnap_system
install_dependencies
download_checkmk_agent
install_checkmk_agent
configure_agent_service

echo -e "\n${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  CheckMK Agent installato con successo!            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo -e "\n${CYAN}Installare anche FRPC Client?${NC}"
echo -ne "${YELLOW}[s/N]: ${NC}"
read -r INSTALL_FRPC_INPUT
INSTALL_FRPC="no"

if [[ "$INSTALL_FRPC_INPUT" =~ ^[sS]$ ]]; then
    INSTALL_FRPC="yes"
    install_frpc
    configure_frpc
fi

configure_autostart
start_services
show_summary

exit 0

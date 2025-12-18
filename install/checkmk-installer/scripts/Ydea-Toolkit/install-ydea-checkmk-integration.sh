#!/usr/bin/env bash
set -euo pipefail

echo "ERROR: this script was quarantined because it was syntactically broken." >&2
echo "A copy of the previous content was saved next to this file." >&2
exit 1

: <<'CORRUPTED_391c70ba9f2748a79ddbf2223470c5a5'
#!/bin/bash
/usr/bin/env bash
# install-ydea-checkmk-integration.sh
# Script di installazione rapida integrazione CheckMK ÔåÆ Ydeaset -euo pipefail
# Colori output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' 
# No Color
# Configurazione
CHECKMK_SITE="${CHECKMK_SITE:-monitoring}"
CHECKMK_NOTIFY_DIR="/omd/sites/${CHECKMK_SITE}/local/share/check_mk/notifications"
YDEA_TOOLKIT_DIR="${YDEA_TOOLKIT_DIR:-/opt/ydea-toolkit}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo -e "${BLUE}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"
echo -e "${BLUE}Ôòæ     ­ƒÄ½ Installazione Integrazione CheckMK ÔåÆ Ydea           Ôòæ${NC}"
echo -e "${BLUE}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"
echo ""
# Funzioni utilityinfo() { 
echo -e "${BLUE}Ôä╣´©Å  $*${NC}"; }success() { 
echo -e "${GREEN}Ô£à $*${NC}"; }warn() { 
echo -e "${YELLOW}ÔÜá´©Å  $*${NC}"; }error() { 
echo -e "${RED}ÔØî $*${NC}" >&2; }check_root() {  if [[ $EUID -ne 0 ]]; then    error "Questo script deve essere eseguito come root"    
echo "  Usa: su
do $0"
    exit 1  fi}check_checkmk() {  if [[ ! -d "/omd/sites/${CHECKMK_SITE}" ]]; then    error "Sito CheckMK '${CHECKMK_SITE}' non trovato"    
echo "  Verifica nome sito o usa: export 
CHECKMK_SITE='nome_sito'"
    exit 1  fi  success "CheckMK sito '${CHECKMK_SITE}' trovato"}check_ydea_toolkit() {  if [[ ! -d "$YDEA_TOOLKIT_DIR" ]]; then    warn "Directory Ydea Toolkit non trovata: $YDEA_TOOLKIT_DIR"    read -p "Vuoi crearla? (y/n) " -n 1 -r    
echo    if [[ $REPLY =~ ^[Yy]$ ]]; then      mkdir -p "$YDEA_TOOLKIT_DIR"      success "Directory creata: $YDEA_TOOLKIT_DIR"
else      error "Impossibile continuare senza Ydea Toolkit"
    exit 1    fi
else    success "Ydea Toolkit trovato: $YDEA_TOOLKIT_DIR"  fi}install_scripts() {  info "Installazione script di notifica CheckMK..."    
# Determina percorso script-notify-checkmk (supporta sia struttura normale che sparse-checkout)  local NOTIFY_SCRIPT_DIR  if [[ -d "${SCRIPT_DIR}/script-notify-checkmk" ]]; then
    NOTIFY_SCRIPT_DIR="${SCRIPT_DIR}/script-notify-checkmk"
elif [[ -d "$(dirname "${SCRIPT_DIR}")/script-notify-checkmk" ]]; then
    NOTIFY_SCRIPT_DIR="$(dirname "${SCRIPT_DIR}")/script-notify-checkmk"
else    error "Cartella script-notify-checkmk non trovata"    
echo "  Provato: ${SCRIPT_DIR}/script-notify-checkmk"    
echo "  Provato: $(dirname "${SCRIPT_DIR}")/script-notify-checkmk"
    exit 1  fi    info "Usan
do script da: ${NOTIFY_SCRIPT_DIR}"    
# Copia ydea_realip  if [[ -f "${NOTIFY_SCRIPT_DIR}/ydea_realip" ]]; then    cp "${NOTIFY_SCRIPT_DIR}/ydea_realip" "$CHECKMK_NOTIFY_DIR/"    chmod +x "${CHECKMK_NOTIFY_DIR}/ydea_realip"    success "ydea_realip installato"
else    error "File ydea_realip non trovato in ${NOTIFY_SCRIPT_DIR}/"
    exit 1  fi    
# Copia mail_ydea_down  if [[ -f "${NOTIFY_SCRIPT_DIR}/mail_ydea_down" ]]; then    cp "${NOTIFY_SCRIPT_DIR}/mail_ydea_down" "$CHECKMK_NOTIFY_DIR/"    chmod +x "${CHECKMK_NOTIFY_DIR}/mail_ydea_down"    success "mail_ydea_down installato"
else    warn "File mail_ydea_down non trovato (opzionale)"  fi    
# Copia health monitor (supporta sia percorso relativo che assoluto)  info "Installazione health monitor..."  local HEALTH_MONITOR  if [[ -f "${SCRIPT_DIR}/ydea-health-monitor.sh" ]]; then
    HEALTH_MONITOR="${SCRIPT_DIR}/ydea-health-monitor.sh"
elif [[ -f "${SCRIPT_DIR}/Ydea-Toolkit/ydea-health-monitor.sh" ]]; then
    HEALTH_MONITOR="${SCRIPT_DIR}/Ydea-Toolkit/ydea-health-monitor.sh"
else    error "File ydea-health-monitor.sh non trovato"
    exit 1  fi    cp "$HEALTH_MONITOR" "$YDEA_TOOLKIT_DIR/"  chmod +x "${YDEA_TOOLKIT_DIR}/ydea-health-monitor.sh"  success "ydea-health-monitor.sh installato"}setup_env() {  info "Configurazione file .env..."    local env_file="${YDEA_TOOLKIT_DIR}/.env"    if [[ -f "$env_file" ]]; then    warn "File .env gi├á esistente, salvo backup"    cp "$env_file" "${env_file}.backup.$(date +%Y%m%d_%H%M%S)"  fi    
# Copia .env template se esiste  if [[ -f "${SCRIPT_DIR}/Ydea-Toolkit/.env" ]]; then    cp "${SCRIPT_DIR}/Ydea-Toolkit/.env" "$env_file"    success "Template .env copiato"  fi
echo ""  warn "ÔÜá´©Å  IMPORTANTE: Configura le credenziali Ydea in:"  
echo "  $env_file"  
echo ""  
echo "Modifica le righe:"  
echo "  export 
YDEA_ID=\"il_tuo_id\""  
echo "  export 
YDEA_API_KEY=\"la_tua_api_key\""  
echo "  export 
YDEA_ALERT_EMAIL=\"massimo.palazzetti@nethesis.it\""  
echo ""    read -p "Vuoi modificarlo ora? (y/n) " -n 1 -r  
echo  if [[ $REPLY =~ ^[Yy]$ ]]; then    ${EDITOR:-nano} "$env_file"  fi}test_connection() {  info "Test connessione Ydea API..."    if [[ ! -f "${YDEA_TOOLKIT_DIR}/ydea-toolkit.sh" ]]; then    warn "ydea-toolkit.sh non trovato, skip test"    return  fi    cd "$YDEA_TOOLKIT_DIR"  if source .env && ./ydea-toolkit.sh login 2>&1 | grep -q "Login effettuato"; then    success "Connessione Ydea OK"
else    warn "Test connessione fallito - verifica credenziali in .env"  fi}setup_cron() {  info "Configurazione cron job per health monitor..."    local cron_line="*/15 * * * * ${YDEA_TOOLKIT_DIR}/ydea-health-monitor.sh >> /var/log/ydea_health.log 2>&1"    
# Controlla se gi├á esiste  if crontab -l 2>/dev/null | grep -q "ydea-health-monitor"; then    warn "Cron job gi├á configurato"
else    
# Aggiungi al crontab    (crontab -l 2>/dev/null; 
echo "
# Ydea Health Monitor - ogni 15 minuti"; 
echo "$cron_line") | crontab -    success "Cron job configurato (ogni 15 minuti)"  fi    
# Crea file log  touch /var/log/ydea_health.log  chmod 666 /var/log/ydea_health.log  success "Log file creato: /var/log/ydea_health.log"}create_cache_files() {  info "Inizializzazione file cache..."    
echo '{}' > /tmp/ydea_checkmk_tickets.json  chmod 666 /tmp/ydea_checkmk_tickets.json    
echo '{}' > /tmp/ydea_checkmk_flapping.json  chmod 666 /tmp/ydea_checkmk_flapping.json    success "File cache inizializzati"}show_next_steps() {  
echo ""  
echo -e "${GREEN}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"  
echo -e "${GREEN}Ôòæ              Ô£à Installazione Completata!                   Ôòæ${NC}"  
echo -e "${GREEN}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"  
echo ""  
echo -e "${BLUE}­ƒôï PROSSIMI PASSI:${NC}"  
echo ""  
echo "1´©ÅÔâú  Configura notification rule in CheckMK:"  
echo "   ÔåÆ Setup ÔåÆ Notifications ÔåÆ Add rule"  
echo "   ÔåÆ Script: ydea_realip"  
echo ""  
echo "2´©ÅÔâú  Verifica credenziali Ydea:"  
echo "   ÔåÆ ${YDEA_TOOLKIT_DIR}/.env"  
echo ""  
echo "3´©ÅÔâú  Test manuale:"  
echo "   ÔåÆ cd ${YDEA_TOOLKIT_DIR}"  
echo "   ÔåÆ source .env"  
echo "   ÔåÆ ./ydea-toolkit.sh login"  
echo ""  
echo "4´©ÅÔâú  Monitora log:"  
echo "   ÔåÆ tail -f /var/log/ydea_health.log"  
echo "   ÔåÆ tail -f /omd/sites/${CHECKMK_SITE}/var/log/notify.log"  
echo ""  
echo "5´©ÅÔâú  Documentazione completa:"  
echo "   ÔåÆ ${YDEA_TOOLKIT_DIR}/README-CHECKMK-INTEGRATION.md"  
echo ""  
echo -e "${YELLOW}ÔÜá´©Å  RICORDA: Configura le credenziali in .env prima dell'uso!${NC}"  
echo ""}
# Main installationmain() {  check_root  check_checkmk  check_ydea_toolkit  install_scripts  setup_env  create_cache_files  setup_cron  test_connection  show_next_steps}mainexit 0

CORRUPTED_391c70ba9f2748a79ddbf2223470c5a5


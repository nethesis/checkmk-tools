
#!/bin/bash
/bin/bash
#
# Script per aggiornare SOLO gli script esistenti dal repository
# NON aggiunge nuovi script, SOSTITUISCE solo quelli gi├á presenti
#set -e
# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'log() { 
echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }log_success() { 
echo -e "${GREEN}Ô£ô${NC} $1"; }log_warning() { 
echo -e "${YELLOW}ÔÜá${NC} $1"; }log_error() { 
echo -e "${RED}Ô£ù${NC} $1" >&2; }
# Configurazione
REPO_DIR="${1:-/opt/checkmk-tools}"
BACKUP_DIR="/tmp/scripts-backup-$(date +%Y%m%d-%H%M%S)"
UPDATED=0log "========================================"log "AGGIORNAMENTO SCRIPT ESISTENTI"log "========================================"log "Repository: $REPO_DIR"log "Backup: $BACKUP_DIR"log ""
# Verifica repositoryif [[ ! -d "$REPO_DIR" ]]; then    log_error "Repository non trovato: $REPO_DIR"    exit 1fi
# Aggiorna repositorylog "Aggiornamento repository..."cd "$REPO_DIR"if ! git diff --quiet || ! git diff --cached --quiet; then    log_warning "Modifiche locali rilevate, salvataggio..."    git stash push -m "Auto-stash $(date +%Y%m%d-%H%M%S)" >/dev/null 2>&1figit pull origin main 2>&1 | grep -v "Already up to date" || truelog_success "Repository aggiornato"log ""mkdir -p "$BACKUP_DIR"
# Funzione per aggiornare SOLO file esistentiupdate_existing_scripts() {    local repo_subdir="$1"  
# es: script-notify-checkmk    local system_dir="$2"   
# es: /opt/omd/sites/monitoring/local/share/check_mk/notifications    local label="$3"    local count=0        local src_dir="$REPO_DIR/$repo_subdir"        if [[ ! -d "$src_dir" ]]; then        log_warning "Directory repo non trovata: $src_dir"        return    fi        if [[ ! -d "$system_dir" ]]; then        log_warning "Directory sistema non trovata: $system_dir"        return    fi        
# Cerca file esistenti nel sistema    cd "$system_dir"    for existing_file in *; do        
# Verifica che sia un file valido        if [[ ! -f "$existing_file" ]] || [[ "$existing_file" =~ \.(md|backup|bak|disabled)$ ]] || [[ "$existing_file" =~ ^(backup-|\.git) ]]; then            continue        fi                
# Verifica se esiste versione aggiornata nel repo        if [[ -f "$src_dir/$existing_file" ]]; then            
# Backup            mkdir -p "$BACKUP_DIR/$label"            cp "$existing_file" "$BACKUP_DIR/$label/"                        
# Aggiorna            cp "$src_dir/$existing_file" "$system_dir/"            log "  - $existing_file"            ((count++))        fi    done        if [[ $count -gt 0 ]]; then        log_success "$label: $count file aggiornati"        ((UPDATED+=count))    else        log_warning "$label: nessun file da aggiornare"    fi}
# 1. NOTIFICHE CHECKMKlog "=== 1. Script notifiche CheckMK ==="update_existing_scripts \    "script-notify-checkmk" \    "/opt/omd/sites/monitoring/local/share/check_mk/notifications" \    "Notifiche"
# 2. CHECK AGENTS - NS7if [[ -d "$REPO_DIR/script-check-ns7" ]]; then    log "=== 2. Script check NethServer 7 ==="    update_existing_scripts \        "script-check-ns7/polling" \        "/usr/lib/check_mk_agent/plugins" \        "NS7-polling"    update_existing_scripts \        "script-check-ns7/nopolling" \        "/usr/lib/check_mk_agent/local" \        "NS7-nopolling"fi
# 3. CHECK AGENTS - NS8if [[ -d "$REPO_DIR/script-check-ns8" ]]; then    log "=== 3. Script check NethServer 8 ==="    update_existing_scripts \        "script-check-ns8/polling" \        "/usr/lib/check_mk_agent/plugins" \        "NS8-polling"    update_existing_scripts \        "script-check-ns8/nopolling" \        "/usr/lib/check_mk_agent/local" \        "NS8-nopolling"fi
# 4. CHECK AGENTS - UBUNTUif [[ -d "$REPO_DIR/script-check-ubuntu" ]]; then    log "=== 4. Script check Ubuntu ==="    update_existing_scripts \        "script-check-ubuntu/polling" \        "/usr/lib/check_mk_agent/plugins" \        "Ubuntu-polling"    if [[ -d "$REPO_DIR/script-check-ubuntu/nopolling" ]]; then        update_existing_scripts \            "script-check-ubuntu/nopolling" \            "/usr/lib/check_mk_agent/local" \            "Ubuntu-nopolling"    fifi
# 5. CHECK AGENTS - PROXMOXif [[ -d "$REPO_DIR/Proxmox" ]]; then    log "=== 5. Script Proxmox ==="    if [[ -d "$REPO_DIR/Proxmox/polling" ]]; then        update_existing_scripts \            "Proxmox/polling" \            "/usr/lib/check_mk_agent/plugins" \            "Proxmox-polling"    fi    if [[ -d "$REPO_DIR/Proxmox/nopolling" ]]; then        update_existing_scripts \            "Proxmox/nopolling" \            "/usr/lib/check_mk_agent/local" \            "Proxmox-nopolling"    fifi
# 6. SCRIPT TOOLSlog "=== 6. Script tools ==="update_existing_scripts \    "script-tools" \    "/opt/omd/sites/monitoring/local/bin" \    "Tools"
# 7. YDEA TOOLKITlog "=== 7. Ydea Toolkit ==="update_existing_scripts \    "Ydea-Toolkit" \    "/opt/ydea-toolkit" \    "Ydea-Toolkit"
# FIX PERMESSIlog ""log "=== Fix permessi e ownership ==="chmod -R 755 /opt/omd/sites/monitoring/local/share/check_mk/notifications/* 2>/dev/null || truechmod -R 755 /opt/omd/sites/monitoring/local/bin/*.sh 2>/dev/null || truechmod -R 755 /opt/ydea-toolkit/*.sh 2>/dev/null || truechmod -R 755 /usr/lib/check_mk_agent/plugins/*.sh 2>/dev/null || truechmod -R 755 /usr/lib/check_mk_agent/local/*.sh 2>/dev/null || truechown -R monitoring:monitoring /opt/omd/sites/monitoring/local/ 2>/dev/null || truelog_success "Permessi aggiornati"
# RIEPILOGOlog ""log "========================================"log "RIEPILOGO"log "========================================"log_success "File aggiornati: $UPDATED"log "Backup salvato: $BACKUP_DIR"log ""
# VERIFICA FILE PRINCIPALIlog "=== Verifica file principali ==="log ""log "Notifiche CheckMK:"ls -lh /opt/omd/sites/monitoring/local/share/check_mk/notifications/{ydea_realip,mail_realip,telegram_realip} 2>/dev/null || log_warning "File notifiche non trovati"log ""log "Check agents (primi 5):"ls -lh /usr/lib/check_mk_agent/plugins/*.sh 2>/dev/null | head -5 || log_warning "Plugin non trovati"log ""log "Tools (primi 5):"ls -lh /opt/omd/sites/monitoring/local/bin/*.sh 2>/dev/null | head -5 || log_warning "Tools non trovati"log ""log_success "Ô£ô Aggiornamento completato!"log ""log "Per ripristinare backup: cp -r $BACKUP_DIR/* /"exit 0

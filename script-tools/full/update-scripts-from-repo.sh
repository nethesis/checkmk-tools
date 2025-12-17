#!/bin/bash
#
# Script per aggiornare automaticamente TUTTI gli script .sh del sistema
# Sostituisce gli script locali con le versioni "r*" dal repository
#
# Uso: ./update-scripts-from-repo.sh [DIRECTORY_REPO] [SEARCH_PATH] [--auto]
#
# --auto: modalit├á automatica, cerca in tutto il sistema (/opt, /usr/local, /home)
#set -e
# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' 
# No Color
# Log functionlog() {    
echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"}log_success() {    
echo -e "${GREEN}Ô£ô${NC} $1"}log_warning() {    
echo -e "${YELLOW}ÔÜá${NC} $1"}log_error() {    
echo -e "${RED}Ô£ù${NC} $1"}
# Parametri
REPO_DIR="${1:-/opt/checkmk-tools}"
AUTO_MODE=false
# Check per modalit├á auto
if [[ "$2" == "--auto" ]] || [[ "$3" == "--auto" ]]; then
    AUTO_MODE=true    
SEARCH_PATHS=("/")  
# Cerca in tutto il sistema
else    
SEARCH_PATH="${2:-/opt/omd}"    
SEARCH_PATHS=("$SEARCH_PATH")fi
BACKUP_DIR="/tmp/script-backup-$(date +%Y%m%d-%H%M%S)"
# Verifica che le directory esistano
if [[ ! -d "$REPO_DIR" ]]; then    log_error "Directory repository non trovata: $REPO_DIR"
    exit 1filog "========================================"log "UPDATE SCRIPT DA REPOSITORY"log "========================================"log "Repository: $REPO_DIR"
if $AUTO_MODE; then    log "Modalit├á: AUTOMATICA (sistema completo)"    log "Ricerca in: / (tutto il filesystem)"    log ""    log "ÔÜá´©Å  ATTENZIONE: La scansione completa pu├▓ richiedere alcuni minuti"
else    log "Modalit├á: MANUALE"    log "Ricerca in: ${SEARCH_PATHS[0]}"filog ""
# Aggiorna il repositorylog "Aggiornamento repository..."cd "$REPO_DIR"
# Salva modifiche locali se esistono
if ! git diff --quiet || ! git diff --cached --quiet; then    log_warning "Modifiche locali rilevate, salvataggio temporaneo..."    git stash push -m "Auto-stash before update $(date +%Y%m%d-%H%M%S)" >/dev/null 2>&1figit pull origin main 2>&1 | grep -v "Already up to date" || truelog_success "Repository aggiornato"log ""
# Crea directory di backupmkdir -p "$BACKUP_DIR"log "Directory backup: $BACKUP_DIR"log ""
# Contatori
UPDATED=0
SKIPPED=0
ERRORS=0
# Array per tracking sostituzionideclare -A REPLACEMENTSlog "Scansione script .sh nel sistema..."log ""
# Scansione di tutte le directory specificatefor search_dir in "${SEARCH_PATHS[@]}"; do    if [[ ! -d "$search_dir" ]]; then        log_warning "Directory non trovata, skip: $search_dir"        continue    fi        log "Scansione: $search_dir"        
# Trova tutti gli script .sh E file eseguibili senza estensione    
# Escludi directory di sistema se si scansiona da root    while 
IFS= read -r -d '' target_script; do        script_name=$(basename "$target_script")        script_dir=$(dirname "$target_script")                
# Salta file di backup e temporanei        if [[ "$script_name" =~ \.(backup|bak|old|tmp)$ ]] || [[ "$script_name" =~ ^\..*$ ]]; then            continue        fi                
# Salta se gi├á ├¿ una versione "r*"        if [[ "$script_name" =~ ^r.* ]]; then            continue        fi                
# Salta file nel repository stesso per evitare conflitti        if [[ "$target_script" == "$REPO_DIR"* ]]; then            continue        fi                
# Cerca la versione "r*" nel repo (in tutte le sottodirectory)        repo_script=$(find "$REPO_DIR" -type f -name "r${script_name}" 2>/dev/null | head -1)                if [[ -n "$repo_script" && -f "$repo_script" ]]; then
    repo_subdir=$(basename "$(dirname "$repo_script")")            log "Trovato: ${YELLOW}$script_dir/$script_name${NC}"            log "      -> ${GREEN}${repo_subdir}/r${script_name}${NC}"                        
# Backup dello script originale            backup_path="$BACKUP_DIR${script_dir}"            mkdir -p "$backup_path"            cp "$target_script" "$backup_path/"                        
# Verifica che lo script repo sia vali
do (bash o eseguibile generico)            if bash -n "$repo_script" 2>/dev/null || [[ -x "$repo_script" ]]; then                
# Copia e sostituisci                cp "$repo_script" "$target_script"                chmod +x "$target_script"                                
# Mantieni owner originale se possibile                original_owner=$(stat -c '%U:%G' "$target_script" 2>/dev/null || 
echo "root:root")                chown "$original_owner" "$target_script" 2>/dev/null || true                                log_success "Aggiornato: $script_dir/$script_name"                REPLACEMENTS["$script_dir/$script_name"]="r${script_name}"                ((UPDATED++))            else                log_error "Errore sintassi in r${script_name}, skip"                ((ERRORS++))            fi        fi            done < <(        if [[ "$search_dir" == "/" ]]; then            
# Escludi directory di sistema per scansione root            find / \( -path /proc -o -path /sys -o -path /dev -o -path /run -o -path /tmp -o -path /var/tmp -o -path '*/snap' -o -path '*/.git' \) -prune -o -type f \( -name "*.sh" -o -executable \) -print0 2>/dev/null        else            find "$search_dir" -type f \( -name "*.sh" -o -executable \) -print0 2>/dev/null        fi    )donelog ""log "========================================"log "RIEPILOGO AGGIORNAMENTO"log "========================================"log_success "Aggiornati: $UPDATED script"log_warning "Trovati ma non aggiornati: $SKIPPED script"
if [[ $ERRORS -gt 0 ]]; then    log_error "Errori: $ERRORS script"filog ""if [[ $UPDATED -gt 0 ]]; then    log "Script sostituiti:"    for original in "${!REPLACEMENTS[@]}"; do        
echo "  ÔÇó $original ÔåÆ ${REPLACEMENTS[$original]}"    done    log ""        log "========================================"    log "VERIFICA FILE SOSTITUITI"    log "========================================"    log "Controllo presenza e integrit├á dei file aggiornati..."    log ""        verify_success=0    verify_failed=0        for original in "${!REPLACEMENTS[@]}"; do        if [[ -f "$original" ]]; then            
# Verifica che sia eseguibile            if [[ -x "$original" ]]; then                
# Verifica che sia un file bash vali
do (se ├¿ uno script bash)                if head -1 "$original" 2>/dev/null | grep -q "bash"; then                    if bash -n "$original" 2>/dev/null; then                        log_success "OK: $original (presente, eseguibile, sintassi valida)"                        ((verify_success++))                    else                        log_error "ERRORE SINTASSI: $original"                        ((verify_failed++))                    fi                else                    log_success "OK: $original (presente, eseguibile)"                    ((verify_success++))                fi            else                log_warning "WARN: $original (presente ma non eseguibile)"                ((verify_failed++))            fi        else            log_error "MANCANTE: $original"            ((verify_failed++))        fi    done        log ""    log "Verifica completata: ${verify_success} OK, ${verify_failed} problemi"    log ""    log "Backup salvato in: $BACKUP_DIR"    log ""    log_success "Ô£ô Aggiornamento completato!"    log ""    log "Per ripristinare il backup:"    log "  cp -r $BACKUP_DIR/* /"else    log_warning "Nessuno script aggiornato"    rm -rf "$BACKUP_DIR" 2>/dev/null || truefilog ""exit 0

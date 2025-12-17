
#!/bin/bash
/bin/bash
# ==========================================================
#  Auto Git Sync - Clone iniziale e Pull automatico
#  Clona il repository alla prima esecuzione e poi
#  esegue git pull ogni minuto automaticamente
#  Autore: ChatGPT per Marzio Bordin
# ==========================================================
# Imposta PATH per systemdexport 
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# Configurazione
REPO_URL="https://github.com/Coverup20/checkmk-tools.git"
# Cerca il repository: prima /opt, poi /root, poi $HOMEif [[ -d "/opt/checkmk-tools/.git" ]]; then    
TARGET_DIR="/opt/checkmk-tools"elif [[ -d "/root/checkmk-tools/.git" ]]; then    
TARGET_DIR="/root/checkmk-tools"elif [[ -d "$HOME/checkmk-tools/.git" ]]; then    
TARGET_DIR="$HOME/checkmk-tools"else    
TARGET_DIR="$HOME/checkmk-tools"  
# Default se non esiste ancorafi
SYNC_INTERVAL="${1:-60}"  
# Primo parametro o default 60 secondi
LOG_FILE="/var/log/auto-git-sync.log"
# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' 
# No Color
# ==========================================================
# Funzioni di utilit├á
# ==========================================================log_message() {    local timestamp    timestamp=$(date '+%Y-%m-%d %H:%M:%S')    
echo "[$timestamp] $1" | tee -a "$LOG_FILE" 2>/dev/null || 
echo "[$timestamp] $1"}print_info() {    
echo -e "${BLUE}Ôä╣´©Å  $1${NC}"    log_message "INFO: $1"}print_success() {    
echo -e "${GREEN}Ô£à $1${NC}"    log_message "SUCCESS: $1"}print_warning() {    
echo -e "${YELLOW}ÔÜá´©Å  $1${NC}"    log_message "WARNING: $1"}print_error() {    
echo -e "${RED}ÔØî $1${NC}"    log_message "ERROR: $1"}print_header() {    
echo -e "\n${CYAN}========================================${NC}"    
echo -e "${CYAN}  $1${NC}"    
echo -e "${CYAN}========================================${NC}\n"}
# ==========================================================
# Verifica e clona repository se necessario
# ==========================================================init_repository() {    print_header "Inizializzazione Repository"        
# Verifica se la directory esiste    if [[ -d "$TARGET_DIR" ]]; then        
# Verifica se ├¿ un repository git valido        if [[ -d "$TARGET_DIR/.git" ]]; then            print_success "Repository gi├á esistente in: $TARGET_DIR"                        
# Verifica il remote            cd "$TARGET_DIR" || exit 1            local current_remote            current_remote=$(timeout 10 git remote get-url origin 2>/dev/null)                        if [[ "$current_remote" == "$REPO_URL" ]]; then                print_success "Remote corretto: $REPO_URL"            else                print_warning "Remote diverso rilevato: $current_remote"                print_info "Aggiorno remote a: $REPO_URL"                git remote set-url origin "$REPO_URL"            fi                        return 0        else            print_warning "Directory esistente ma non ├¿ un repository git"            print_info "Rimuovo directory e procedo con il clone..."            rm -rf "$TARGET_DIR"        fi    fi        
# Clone del repository    print_info "Clonazione repository da: $REPO_URL"    print_info "Destinazione: $TARGET_DIR"        if timeout 120 git clone "$REPO_URL" "$TARGET_DIR"; then        print_success "Repository clonato con successo!"        cd "$TARGET_DIR" || exit 1                
# Mostra informazioni sul repository        local branch        branch=$(git branch --show-current)        local commit        commit=$(git rev-parse --short HEAD)        print_info "Branch: $branch"        print_info "Commit: $commit"                return 0    else        print_error "Errore durante il clone del repository"        return 1    fi}
# ==========================================================
# Esegue git pull con controlli robusti
# ==========================================================do_git_pull() {    cd "$TARGET_DIR" || {        print_error "Impossibile accedere alla directory: $TARGET_DIR"        return 1    }        
# Verifica integrit├á repository    if ! git rev-parse --git-dir > /dev/null 2>&1; then        print_error "Repository corrotto, riclonazione necessaria"        cd ..        rm -rf "$TARGET_DIR"        init_repository        return $?    fi        
# Salva commit corrente    local old_commit    old_commit=$(git rev-parse --short HEAD 2>/dev/null)    local current_branch    current_branch=$(git branch --show-current 2>/dev/null)        
# Verifica se siamo su un branch valido    if [[ -z "$current_branch" ]]; then        print_warning "Detached HEAD rilevato, checkout forzato su main..."        
# Usa -B per forzare creazione/reset del branch locale a origin/main        if ! git checkout -B main origin/main 2>&1 | tee -a "$LOG_FILE"; then            print_error "Impossibile fare checkout su main"            return 1        fi        current_branch="main"    fi        
# Verifica se ci sono modifiche locali o file non tracciati    if ! git diff-index --quiet HEAD -- 2>/dev/null || [[ -n $(git ls-files --others --exclude-standard) ]]; then        print_warning "Modifiche locali o file non tracciati rilevati"                
# Reset HARD per allineare completamente al remote        print_info "Reset HARD per allineare al remote (modifiche locali PERSE)..."        git reset --hard HEAD >/dev/null 2>&1        git clean -fd >/dev/null 2>&1        print_success "Repository locale pulito"    fi        
# Fetch per vedere aggiornamenti remoti    print_info "Verifica aggiornamenti remoti..."    if ! timeout 60 git fetch origin 2>&1 | tee -a "$LOG_FILE"; then        print_error "Errore durante fetch (timeout o errore rete)"        return 1    fi        
# Verifica se siamo dietro al remote    local local_commit    local_commit=$(git rev-parse HEAD)    local remote_commit    remote_commit=$(git rev-parse origin/$current_branch 2>/dev/null)        if [[ -z "$remote_commit" ]]; then        print_warning "Branch remoto non trovato: origin/$current_branch"        print_info "Tento con origin/main..."        current_branch="main"        remote_commit=$(git rev-parse origin/main 2>/dev/null)                if [[ -z "$remote_commit" ]]; then            print_error "Impossibile trovare branch remoto valido"            return 1        fi                git checkout main 2>/dev/null || return 1    fi        
# Se locale e remote divergono, FORZA allineamento al remote    if [[ "$local_commit" != "$remote_commit" ]]; then        local behind_count        behind_count=$(git rev-list --count HEAD..origin/$current_branch 2>/dev/null || 
echo "?")        local ahead_count        ahead_count=$(git rev-list --count origin/$current_branch..HEAD 2>/dev/null || 
echo "0")                if [[ "$ahead_count" != "0" ]] && [[ "$ahead_count" != "?" ]]; then            print_warning "Repository locale ├¿ AVANTI di $ahead_count commit rispetto al remote"            print_info "RESET FORZATO al remote per allineamento..."        else            print_info "Repository locale ├¿ DIETRO di $behind_count commit"        fi                
# HARD reset al remote e pulizia aggressiva per gestire rinominazioni        if timeout 30 git reset --hard origin/$current_branch 2>&1 | tee -a "$LOG_FILE"; then            local new_commit            new_commit=$(git rev-parse --short HEAD)                        
# Pulizia aggressiva di file/directory non tracciati (incluse directory rinominate)            if git clean -fdx 2>&1 | tee -a "$LOG_FILE"; then                print_info "Pulizia completata: rimossi file/directory non tracciati"            fi                        print_success "Repository FORZATO ad allinearsi: $old_commit ÔåÆ $new_commit"                        
# Rendi eseguibili tutti gli script .sh            print_info "Aggiornamento permessi script..."            find "$TARGET_DIR" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null            print_success "Permessi aggiornati per file .sh"                        
# Mostra i file modificati            if [[ -n "$old_commit" ]] && [[ "$old_commit" != "$new_commit" ]]; then                print_info "File modificati:"                git diff --name-status "$old_commit" "$new_commit" 2>/dev/null | while read -r status file; do                    case "$status" in                        A) 
echo "  ${GREEN}+ $file${NC}" ;;                        M) 
echo "  ${YELLOW}~ $file${NC}" ;;                        D) 
echo "  ${RED}- $file${NC}" ;;                        *) 
echo "  $status $file" ;;                    esac                done            fi                        return 0        else            print_error "Errore durante reset al remote"            return 1        fi    else        print_info "Repository gi├á aggiornato (nessuna modifica)"                
# Aggiorna comunque i permessi per sicurezza        find "$TARGET_DIR" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null                return 0    fi}
# ==========================================================
# Loop principale
# ==========================================================run_sync_loop() {    print_header "Auto Git Sync Attivo"        print_info "Repository: $REPO_URL"    print_info "Directory locale: $TARGET_DIR"    print_info "Intervallo sync: ${SYNC_INTERVAL}s (ogni minuto)"    print_info "Log file: $LOG_FILE"    
echo ""    print_warning "Premi Ctrl+C per interrompere"    
echo ""        local sync_count=0        while true; do        sync_count=$((sync_count + 1))                
echo -e "${CYAN}ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü${NC}"        print_info "Sync 
#$sync_count - $(date '+%Y-%m-%d %H:%M:%S')"                if do_git_pull; then            print_success "Sync completato"        else            print_error "Sync fallito"        fi                print_info "Prossimo sync tra ${SYNC_INTERVAL}s..."        sleep "$SYNC_INTERVAL"    done}
# ==========================================================
# Gestione segnali
# ==========================================================cleanup() {    
echo ""    print_warning "Ricevuto segnale di interruzione"    print_info "Arresto Auto Git Sync..."    log_message "Auto Git Sync terminato"    exit 0}trap cleanup SIGINT SIGTERM
# ==========================================================
# Main
# ==========================================================main() {    
# Verifica git installato    if ! command -v git &> /dev/null; then        print_error "Git non ├¿ installato"        exit 1    fi        
# Crea directory per log se non esiste    if [[ -w "$(dirname "$LOG_FILE")" ]] || sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null; then        sudo touch "$LOG_FILE" 2>/dev/null || true    else        
LOG_FILE="$HOME/auto-git-sync.log"        print_warning "Usando log file alternativo: $LOG_FILE"    fi        print_header "Auto Git Sync - Avvio"    log_message "=== Auto Git Sync Started ==="        
# Inizializza repository    if ! init_repository; then        print_error "Impossibile inizializzare il repository"        exit 1    fi        
# Esegui primo sync immediato    print_header "Primo Sync"    do_git_pull        
# Avvia loop di sync    run_sync_loop}
# Controlla se script eseguito direttamenteif [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then    main "$@"fi

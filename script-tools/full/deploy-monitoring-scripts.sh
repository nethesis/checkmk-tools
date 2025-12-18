#!/usr/bin/env bash
# ==========================================================
# deploy-monitoring-scripts.sh (fixed)
# Deploy interattivo di script r*.sh nella directory Checkmk agent local
# ==========================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TARGET_DIR="/usr/lib/check_mk_agent/local"

print_header() {
    echo
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo
}

print_info() { echo -e "${BLUE}INFO: $1${NC}"; }
print_success() { echo -e "${GREEN}OK: $1${NC}"; }
print_warning() { echo -e "${YELLOW}WARN: $1${NC}"; }
print_error() { echo -e "${RED}ERR: $1${NC}"; }

require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        print_error "Questo script deve essere eseguito come root"
        exit 1
    fi
}

detect_system() {
    if [[ -f /etc/nethserver-release ]]; then
        echo "ns7"; return
    fi
    if [[ -f /etc/os-release ]]; then
        if grep -qE '^ID="?nethserver"?$' /etc/os-release; then
            if grep -qE '^VERSION_ID="?7"?$' /etc/os-release; then echo "ns7"; return; fi
            if grep -qE '^VERSION_ID="?8"?$' /etc/os-release; then echo "ns8"; return; fi
        fi
        if grep -qiE 'NethServer 8|ns8' /etc/os-release; then
            echo "ns8"; return
        fi
        if grep -qiE 'Ubuntu|Debian' /etc/os-release; then
            echo "ubuntu"; return
        fi
    fi
    if [[ -f /etc/pve/version ]]; then
        echo "proxmox"; return
    fi
    echo "generic"
}

find_repository() {
    local candidates=(
        "/opt/checkmk-tools"
        "/root/checkmk-tools"
        "$HOME/checkmk-tools"
    )
    for d in "${candidates[@]}"; do
        if [[ -d "$d/.git" ]]; then
            echo "$d"
            return
        fi
    done
    echo ""
}

get_category_dir() {
    local system_type="$1"
    local repo_dir="$2"
    case "$system_type" in
        ns7) echo "$repo_dir/script-check-ns7/remote" ;;
        ns8) echo "$repo_dir/script-check-ns8/remote" ;;
        proxmox) echo "$repo_dir/script-check-proxmox/remote" ;;
        ubuntu|generic) echo "$repo_dir/script-check-ubuntu/remote" ;;
        *) echo "" ;;
    esac
}

show_menu_and_get_selection() {
    local category_dir="$1"
    mapfile -t scripts < <(find "$category_dir" -type f -name 'r*.sh' 2>/dev/null | sort)
    if (( ${#scripts[@]} == 0 )); then
        print_error "Nessun file r*.sh trovato in: $category_dir"
        return 1
    fi

    echo -e "${CYAN}Script disponibili:${NC}"
    for i in "${!scripts[@]}"; do
        printf "  %3d) %s\n" $((i+1)) "$(basename "${scripts[$i]}")"
    done
    echo
    echo "Inserisci:"
    echo "  - Numeri separati da spazi (es: 1 3 5)"
    echo "  - 'a' per tutti"
    echo "  - 'n' per nessuno"
    echo

    read -r -p "Selezione: " selection
    selection=${selection:-n}

    if [[ "$selection" =~ ^[Aa]$ ]]; then
        printf '%s\n' "${scripts[@]}"
        return 0
    fi
    if [[ "$selection" =~ ^[Nn]$ ]]; then
        return 0
    fi

    local selected=()
    for num in $selection; do
        if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#scripts[@]} )); then
            selected+=( "${scripts[$((num-1))]}" )
        else
            print_warning "Numero non valido: $num (1-${#scripts[@]})"
        fi
    done

    if (( ${#selected[@]} == 0 )); then
        return 0
    fi
    printf '%s\n' "${selected[@]}"
}

deploy_scripts() {
    local scripts=("$@")

    if [[ ! -d "$TARGET_DIR" ]]; then
        print_warning "Directory $TARGET_DIR non trovata, creazione..."
        mkdir -p "$TARGET_DIR"
    fi

    local deployed=0
    local failed=0
    for script in "${scripts[@]}"; do
        local script_name
        script_name="$(basename "$script")"
        local target_path="$TARGET_DIR/$script_name"
        if cp "$script" "$target_path" 2>/dev/null; then
            chmod +x "$target_path"
            print_success "Installato: $script_name"
            deployed=$((deployed+1))
        else
            print_error "Errore installando: $script_name"
            failed=$((failed+1))
        fi
    done

    echo
    print_info "Deployment completato: installati=$deployed, falliti=$failed"
}

main() {
    print_header "Deploy Monitoring Scripts"
    require_root

    local repo_dir
    repo_dir="$(find_repository)"
    if [[ -z "$repo_dir" ]]; then
        print_error "Repository checkmk-tools non trovato"
        print_info "Posizioni cercate: /opt/checkmk-tools, /root/checkmk-tools, $HOME/checkmk-tools"
        exit 1
    fi
    print_success "Repository trovato: $repo_dir"

    local system_type
    system_type="$(detect_system)"
    print_info "Sistema rilevato: $system_type"

    local category_dir
    category_dir="$(get_category_dir "$system_type" "$repo_dir")"
    if [[ -z "$category_dir" || ! -d "$category_dir" ]]; then
        print_error "Directory script non trovata: $category_dir"
        exit 1
    fi
    print_info "Directory sorgente: $category_dir"
    print_info "Directory destinazione: $TARGET_DIR"
    echo

    local tmp
    tmp="$(mktemp)"
    if ! show_menu_and_get_selection "$category_dir" > "$tmp"; then
        rm -f "$tmp"
        exit 1
    fi
    mapfile -t selected_scripts < <(grep -v '^\s*$' "$tmp" || true)
    rm -f "$tmp"

    if (( ${#selected_scripts[@]} == 0 )); then
        print_info "Nessuno script selezionato"
        exit 0
    fi

    echo
    read -r -p "Procedere con l'installazione degli script selezionati? [S/n]: " confirm
    confirm=${confirm:-S}
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Operazione annullata"
        exit 0
    fi

    deploy_scripts "${selected_scripts[@]}"
    print_success "Operazione completata!"
}

main "$@"

: <<'__CORRUPTED_ORIGINAL_CONTENT__'
#  Rileva il sistema operativo e propone gli script
#  disponibili per il deployment
#  Autore: ChatGPT per Marzio Bordin
# ==========================================================
# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
# Configurazione
REPO_DIR=""
TARGET_DIR="/usr/lib/check_mk_agent/local"
SCRIPT_CATEGORIES=()
# ==========================================================
# Funzioni di utilità
# ==========================================================
print_header() {
	echo ""
	echo -e "${CYAN}========================================${NC}"
	echo -e "${CYAN}  $1${NC}"
	echo -e "${CYAN}========================================${NC}"
	echo ""
}

print_info() {
	echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
	echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
	echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
	echo -e "${RED}✖ $1${NC}"
}
# ==========================================================
# Funzioni di rilevamento sistema
# ==========================================================detect_system() {    local os_type=""        
# Rileva NethServer 7 (cerca nethserver-release o 
VERSION_ID="7")    if [[ -f /etc/nethserver-release ]] || \       ( [[ -f /etc/os-release ]] && grep -qE '
ID="?nethserver|
VERSION_ID="?7' /etc/os-release ); then
    os_type="ns7"        
# Rileva NethServer 8 (cerca 
VERSION_ID="8" o ns8 nel nome)    elif [[ -f /etc/os-release ]] && grep -qE '
VERSION_ID="?8|ns8|NethServer 8' /etc/os-release; then
    os_type="ns8"        
# Rileva Proxmox
elif [[ -f /etc/pve/version ]]; then
    os_type="proxmox"        
# Rileva Ubuntu/Debian
elif [[ -f /etc/os-release ]] && grep -qE "Ubuntu|Debian" /etc/os-release; then
    os_type="ubuntu"        
# Sistema generico
else        os_type="generic"    fi
echo "$os_type"}
# ==========================================================
# Funzioni di ricerca repository
# ==========================================================find_repository() {    if [[ -d "/opt/checkmk-tools/.git" ]]; then
    echo "/opt/checkmk-tools"
elif [[ -d "/root/checkmk-tools/.git" ]]; then
    echo "/root/checkmk-tools"
elif [[ -d "$HOME/checkmk-tools/.git" ]]; then
    echo "$HOME/checkmk-tools"
else        
echo ""    fi}
# ==========================================================
# Funzioni di selezione script
# ==========================================================list_available_scripts() {    local system_type="$1"    local category_dir=""        case "$system_type" in        ns7)            
# NS7: cerca in remote (launcher) per tutti gli script (nopolling + polling)            category_dir="$REPO_DIR/script-check-ns7/remote"            ;;        ns8)            
# NS8: cerca in remote (launcher)            category_dir="$REPO_DIR/script-check-ns8/remote"            ;;        proxmox)            
# Proxmox: cerca in remote (launcher)            category_dir="$REPO_DIR/script-check-proxmox/remote"            ;;        ubuntu|generic)            
# Ubuntu: cerca in remote (launcher)            category_dir="$REPO_DIR/script-check-ubuntu/remote"            ;;        *)            print_error "Tipo di sistema non supportato: $system_type"            return 1            ;;    esac        if [[ ! -d "$category_dir" ]]; then        print_error "Directory script non trovata: $category_dir"        print_info "Contenuto di $REPO_DIR/script-check-ns7/:"        ls -la "$REPO_DIR/script-check-ns7/" 2>&1 || 
echo "Directory non esiste"        return 1    fi        
# Lista tutti gli script .sh nella directory remote (include sottocartelle)    local script_list    script_list=$(find "$category_dir" -type f -name "r*.sh" 2>&1 | sort)        if [[ -z "$script_list" ]]; then        print_error "Nessun file r*.sh trovato in: $category_dir"        print_info "Contenuto della directory:"        ls -la "$category_dir" 2>&1 || 
echo "Impossibile listare directory"        return 1    fi
echo "$script_list"}show_script_menu() {    local system_type="$1"    local category_dir=""    local selected=()    local scripts=()        
# Determina la directory degli script    case "$system_type" in        ns7) category_dir="$REPO_DIR/script-check-ns7/remote" ;;        ns8) category_dir="$REPO_DIR/script-check-ns8/remote" ;;        proxmox) category_dir="$REPO_DIR/Proxmox/remote" ;;        ubuntu|generic) category_dir="$REPO_DIR/script-check-ubuntu/remote" ;;    esac        
# Fallback se remote non esiste, prova polling    if [[ ! -d "$category_dir" ]]; then        case "$system_type" in            ns7) category_dir="$REPO_DIR/script-check-ns7/polling" ;;            ns8) category_dir="$REPO_DIR/script-check-ns8/polling" ;;            proxmox) category_dir="$REPO_DIR/Proxmox/polling" ;;            ubuntu|generic) category_dir="$REPO_DIR/script-check-ubuntu/polling" ;;        esac    fi        
# Header su stderr per evitare cattura    
echo "" >&2    
echo -e "${CYAN}========================================${NC}" >&2    
echo -e "${CYAN}  Script disponibili per $system_type${NC}" >&2    
echo -e "${CYAN}========================================${NC}" >&2    
echo "" >&2        
echo "Directory: $category_dir" >&2        
# Verifica esistenza directory    if [[ ! -d "$category_dir" ]]; then        print_error "Directory non trovata: $category_dir"        print_info "Verifica che il repository sia aggiornato"        return 1    fi
echo "" >&2        
# Crea array con tutti gli script    mapfile -t scripts < <(find "$category_dir" -type f -name "r*.sh" 2>/dev/null | sort)        if [[ ${
#scripts[@]} -eq 0 ]]; then        print_error "Nessuno script trovato"        return 1    fi        
# Mostra lista numerata (su stderr per evitare cattura)    for i in "${!scripts[@]}"; do        printf "%3d) %s\n" $((i+1)) "$(basename "${scripts[$i]}")" >&2    done
echo "" >&2    
echo "Inserisci:" >&2    
echo "  - Numeri separati da spazi (es: 1 3 5 8)" >&2    
echo "  - 'a' per tutti" >&2    
echo "  - 'n' per nessuno" >&2    
echo "" >&2        
# Reindirizza stdin da /dev/tty per questa operazione    exec < /dev/tty    read -r -p "Selezione: " selection >&2        
# Gestisci selezione    if [[ "$selection" == "a" || "$selection" == "A" ]]; then        
# Tutti gli script        selected=("${scripts[@]}")        print_success "Selezionati tutti gli script (${
#selected[@]})" >&2    elif [[ "$selection" == "n" || "$selection" == "N" ]]; then        
# Nessuno script        print_info "Nessuno script selezionato" >&2        return 0    else        
# Selezione per numeri        for num in $selection; do            if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${
#scripts[@]} ]]; then                selected+=("${scripts[$((num-1))]}")            else                print_warning "Numero non vali
do: $num (intervallo: 1-${
#scripts[@]})" >&2            fi        done                if [[ ${
#selected[@]} -eq 0 ]]; then            print_warning "Nessuno script selezionato" >&2            return 0        fi                print_success "Selezionati ${
#selected[@]} script" >&2    fi        
# Ritorna array di script selezionati    for script in "${selected[@]}"; do        
echo "$script"    done}get_script_description() {    local script_path="$1"local script_namelocal script_namescript_name=$(basename "$script_path" .sh)        
# Rimuovi prefisso 'r' dai nomi remote    script_name="${script_name
#r}"        
# Descrizioni comuni    case "$script_name" in        *ssh*) 
echo "Monitoraggio SSH" ;;        *postfix*) 
echo "Monitoraggio Postfix" ;;        *dovecot*) 
echo "Monitoraggio Dovecot" ;;        *webtop*) 
echo "Monitoraggio Webtop" ;;        *cockpit*) 
echo "Monitoraggio Cockpit" ;;        *ransomware*) 
echo "Rilevamento Ransomware" ;;        *sos*) 
echo "Supporto SOS" ;;        *container*) 
echo "Monitoraggio Container" ;;        *podman*) 
echo "Monitoraggio Podman" ;;        *proxmox*) 
echo "Monitoraggio Proxmox" ;;        *disk*) 
echo "Monitoraggio Disco" ;;        *) 
echo "Script di monitoring" ;;    esac}
# ==========================================================
# Funzioni di deployment
# ==========================================================deploy_scripts() {    local -a scripts=("$@")    local deployed=0    local failed=0        print_header "Deployment Script"        
# Crea directory target se non esiste    if [[ ! -d "$TARGET_DIR" ]]; then        print_warning "Directory $TARGET_DIR non trovata, creazione..."        mkdir -p "$TARGET_DIR"    fi        
# Copia ogni script    for script in "${scripts[@]}"; dolocal script_namelocal script_namescript_name=$(basename "$script")        local target_path="$TARGET_DIR/$script_name"                if cp "$script" "$target_path" 2>/dev/null; then            chmod +x "$target_path"            print_success "Installato: $script_name"            ((deployed++))        else            print_error "Errore installan
do: $script_name"            ((failed++))        fi    done
echo ""    print_info "Deployment completato:"    
echo "  - Installati: $deployed"    
echo "  - Falliti: $failed"        return 0}
# ==========================================================
# Main
# ==========================================================main() {    print_header "Deploy Monitoring Scripts"        
# Verifica esecuzione come root    if [[ $EUID -ne 0 ]]; then        print_error "Questo script deve essere eseguito come root"
    exit 1    fi        
# Trova repository    
REPO_DIR=$(find_repository)    if [[ -z "$REPO_DIR" ]]; then        print_error "Repository checkmk-tools non trovato"        print_info "Posizioni cercate:"        
echo "  - /opt/checkmk-tools"        
echo "  - /root/checkmk-tools"        
echo "  - $HOME/checkmk-tools"
    exit 1    fi        print_success "Repository trovato: $REPO_DIR"        
# Rileva sistema    
SYSTEM_TYPE=$(detect_system)        
# Verifica che SYSTEM_TYPE non sia vuoto    if [[ -z "$SYSTEM_TYPE" ]]; then        print_error "Impossibile rilevare il tipo di sistema"
    exit 1    fi        
# Stampa tipo di sistema rilevato    case "$SYSTEM_TYPE" in        ns7)     print_info "Sistema rilevato: NethServer 7" ;;        ns8)     print_info "Sistema rilevato: NethServer 8" ;;        proxmox) print_info "Sistema rilevato: Proxmox VE" ;;        ubuntu)  print_info "Sistema rilevato: Ubuntu/Debian" ;;        *)       print_warning "Sistema non riconosciuto, uso configurazione generica" ;;    esac        
# Mostra menu e ottieni selezione (usa file temporaneo per evitare problemi con stdin in subshell)    
TMP_SELECTION="/tmp/deploy-scripts-selection-$$.txt"    show_script_menu "$SYSTEM_TYPE" > "$TMP_SELECTION"        
# Leggi solo righe non vuote dal file temporaneo    
SELECTED_SCRIPTS=()    while 
IFS= read -r line; do        [[ -n "$line" ]] && SELECTED_SCRIPTS+=("$line")    done < "$TMP_SELECTION"    rm -f "$TMP_SELECTION"        if [[ ${
#SELECTED_SCRIPTS[@]} -eq 0 ]]; then        print_info "Nessuno script da installare"
    exit 0    fi        
# Conferma deployment    
echo ""    exec < /dev/tty    read -r -p "Procedere con l'installazione degli script selezionati? [S/n]: " confirm    if [[ "$confirm" =~ ^[Nn] ]]; then        print_info "Operazione annullata"
    exit 0    fi        
# Deploy    deploy_scripts "${SELECTED_SCRIPTS[@]}"        print_success "Operazione completata!"    print_info "Gli script sono stati installati in: $TARGET_DIR"}
# Esegui mainmain "$@"

__CORRUPTED_ORIGINAL_CONTENT__

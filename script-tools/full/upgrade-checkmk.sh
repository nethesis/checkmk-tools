#!/usr/bin/env bash
# ==========================================================
#  CheckMK RAW - Upgrade Script con Controllo Versione
#  Verifica versione corrente, scarica ultima disponibile,
#  richiede conferma e procede con upgrade automatico
# ==========================================================

set -e

SITE_NAME="monitoring"
CHECKMK_EDITION="cre"  # cre = CheckMK Raw Edition
DOWNLOAD_DIR="/tmp/checkmk-upgrade"
BACKUP_DIR="/opt/omd/backups"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}========================================${NC}\n"
}

print_info() {
    echo -e "${BLUE}INFO${NC}  $1"
}

print_success() {
    echo -e "${GREEN}OK${NC}    $1"
}

print_warning() {
    echo -e "${YELLOW}WARN${NC}  $1"
}

print_error() {
    echo -e "${RED}ERR${NC}   $1" >&2
}

check_prerequisites() {
    print_header "Controllo Prerequisiti"

    if [[ $EUID -ne 0 ]]; then
        print_error "Questo script deve essere eseguito come root"
        exit 1
    fi
    print_success "Esecuzione come root: OK"

    if ! omd sites | grep -q "^${SITE_NAME}\b"; then
        print_error "Sito CheckMK '$SITE_NAME' non trovato"
        echo "Siti disponibili:"
        omd sites
        exit 1
    fi
    print_success "Sito '$SITE_NAME' trovato"

    if ! ping -c 1 checkmk.com &>/dev/null; then
        print_error "Nessuna connessione internet disponibile"
        exit 1
    fi
    print_success "Connessione internet: OK"

    mkdir -p "$DOWNLOAD_DIR"
    print_success "Directory temporanea: $DOWNLOAD_DIR"
}

get_current_version() {
    print_header "Versione Corrente Installata"
    CURRENT_VERSION=$(omd version "$SITE_NAME" | grep -oP '\\d+\\.\\d+\\.\\d+p\\d+' || true)
    if [[ -z "$CURRENT_VERSION" ]]; then
        print_error "Impossibile rilevare la versione corrente"
        exit 1
    fi
    print_info "Versione installata: ${GREEN}${CURRENT_VERSION}${NC}"
}

get_latest_version() {
    print_header "Verifica Ultima Versione Disponibile"
    print_info "Recupero informazioni da checkmk.com..."

    download_page=$(curl -s "https://checkmk.com/download" || true)
    LATEST_VERSION=$(echo "$download_page" | grep -oP 'check-mk-raw-\\K\\d+\\.\\d+\\.\\d+p\\d+' | head -1 || true)

    if [[ -z "$LATEST_VERSION" ]]; then
        print_error "Impossibile recuperare l'ultima versione disponibile"
        exit 1
    fi
    print_info "Ultima versione disponibile: ${GREEN}${LATEST_VERSION}${NC}"
}

compare_versions() {
    local current="$1"
    local latest="$2"

    print_header "Confronto Versioni"
    echo -e "${BLUE}Versione corrente:${NC}    $current"
    echo -e "${BLUE}Versione disponibile:${NC} $latest"
    echo ""

    if [[ "$current" == "$latest" ]]; then
        print_success "Stai già utilizzando l'ultima versione disponibile!"
        echo -e "\n${GREEN}Nessun aggiornamento necessario.${NC}\n"
        exit 0
    fi

    print_warning "È disponibile una nuova versione"
    return 1
}

confirm_upgrade() {
    local current="$1"
    local latest="$2"

    print_header "Conferma Upgrade"
    echo -e "${YELLOW}Stai per aggiornare CheckMK:${NC}"
    echo -e "  Da: ${RED}${current}${NC}"
    echo -e "  A:  ${GREEN}${latest}${NC}"
    echo ""
    echo -e "${YELLOW}Operazioni che verranno eseguite:${NC}"
    echo "  1. Backup automatico del sito corrente"
    echo "  2. Download della nuova versione"
    echo "  3. Stop del sito '$SITE_NAME'"
    echo "  4. Upgrade alla versione installata"
    echo "  5. Avvio del sito aggiornato"
    echo ""

    read -r -p "Vuoi procedere con l'upgrade? (s/N): " confirm
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        print_warning "Upgrade annullato dall'utente"
        exit 0
    fi

    print_success "Upgrade confermato, procedo..."
}

backup_site() {
    print_header "Backup Sito CheckMK"
    mkdir -p "$BACKUP_DIR"

    local backup_file="$BACKUP_DIR/${SITE_NAME}_pre-upgrade_$(date +%Y%m%d_%H%M%S).tar.gz"
    print_info "Creazione backup in: $backup_file"

    if omd backup "$SITE_NAME" "$backup_file"; then
        print_success "Backup completato con successo"
        print_info "File backup: $backup_file"
    else
        print_error "Errore durante il backup"
        exit 1
    fi
}

download_version() {
    local version="$1"
    print_header "Download CheckMK $version"

    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        OS_ID="$ID"
        OS_VERSION_ID="$VERSION_ID"
    else
        print_error "Impossibile rilevare la distribuzione"
        exit 1
    fi

    print_info "Sistema operativo: $OS_ID $OS_VERSION_ID"

    local package_name=""
    case "$OS_ID" in
        ubuntu)
            if [[ "$OS_VERSION_ID" == "24.04" ]]; then
                package_name="check-mk-raw-${version}_0.noble_amd64.deb"
            elif [[ "$OS_VERSION_ID" == "22.04" ]]; then
                package_name="check-mk-raw-${version}_0.jammy_amd64.deb"
            elif [[ "$OS_VERSION_ID" == "20.04" ]]; then
                package_name="check-mk-raw-${version}_0.focal_amd64.deb"
            else
                print_error "Versione Ubuntu non supportata: $OS_VERSION_ID"
                exit 1
            fi
            ;;
        debian)
            if [[ "$OS_VERSION_ID" == "12" ]]; then
                package_name="check-mk-raw-${version}_0.bookworm_amd64.deb"
            elif [[ "$OS_VERSION_ID" == "11" ]]; then
                package_name="check-mk-raw-${version}_0.bullseye_amd64.deb"
            else
                print_error "Versione Debian non supportata: $OS_VERSION_ID"
                exit 1
            fi
            ;;
        *)
            print_error "Distribuzione non supportata: $OS_ID"
            exit 1
            ;;
    esac

    local download_url="https://download.checkmk.com/checkmk/${version}/${package_name}"
    local local_file="/tmp/cmk.deb"

    print_info "URL download: $download_url"
    print_info "File locale: $local_file"

    rm -f "$local_file" 2>/dev/null || true

    print_info "Download in corso..."
    if wget --progress=bar:force -O "$local_file" "$download_url" >/dev/null 2>&1; then
        print_success "Download completato"
    else
        print_error "Errore durante il download"
        rm -f "$local_file" 2>/dev/null || true
        exit 1
    fi

    if [[ ! -s "$local_file" ]]; then
        print_error "File scaricato non valido"
        exit 1
    fi

    print_success "File scaricato: $(du -h "$local_file" | cut -f1)"
}

install_version() {
    local package_file="$1"
    print_header "Installazione Nuova Versione"
    print_info "Installazione del pacchetto: $(basename "$package_file")"

    if [[ "$package_file" == *.deb ]]; then
        if dpkg -i "$package_file"; then
            print_success "Pacchetto installato con successo"
        else
            print_error "Errore durante l'installazione del pacchetto"
            exit 1
        fi
    else
        print_error "Tipo di pacchetto non riconosciuto: $package_file"
        exit 1
    fi
}

upgrade_site() {
    print_header "Upgrade Sito '$SITE_NAME'"

    print_info "Stop del sito..."
    if omd stop "$SITE_NAME"; then
        print_success "Sito fermato"
    else
        print_error "Errore durante lo stop del sito"
        exit 1
    fi

    print_info "Upgrade del sito..."
    if omd update "$SITE_NAME"; then
        print_success "Upgrade completato"
    else
        print_error "Errore durante l'upgrade"
        print_warning "Tentativo di ripartenza del sito..."
        omd start "$SITE_NAME" || true
        exit 1
    fi

    print_info "Avvio del sito aggiornato..."
    if omd start "$SITE_NAME"; then
        print_success "Sito avviato correttamente"
    else
        print_error "Errore durante l'avvio del sito"
        exit 1
    fi
}

verify_upgrade() {
    print_header "Verifica Post-Upgrade"

    new_version=$(omd version "$SITE_NAME" | grep -oP '\\d+\\.\\d+\\.\\d+p\\d+' || true)
    print_info "Versione attuale: $new_version"

    print_info "Controllo status sito..."
    omd status "$SITE_NAME" || true

    print_info "Verifica accesso web..."
    local site_url="http://localhost/${SITE_NAME}"
    if curl -s -o /dev/null -w "%{http_code}" "$site_url" | grep -q "200\|302\|301"; then
        print_success "Sito web accessibile"
    else
        print_warning "Impossibile verificare l'accesso web"
    fi

    print_success "Upgrade completato con successo!"
}

cleanup() {
    print_header "Pulizia File Temporanei"
    read -r -p "Vuoi eliminare i file di download? (s/N): " cleanup_confirm
    if [[ "$cleanup_confirm" =~ ^[sS]$ ]]; then
        rm -rf "$DOWNLOAD_DIR"
        print_success "File temporanei eliminati"
    else
        print_info "File mantenuti in: $DOWNLOAD_DIR"
    fi
}

main() {
    print_header "CheckMK Upgrade Script"

    check_prerequisites
    get_current_version
    get_latest_version
    compare_versions "$CURRENT_VERSION" "$LATEST_VERSION" || true

    confirm_upgrade "$CURRENT_VERSION" "$LATEST_VERSION"
    backup_site
    download_version "$LATEST_VERSION"

    PACKAGE_FILE="/tmp/cmk.deb"
    install_version "$PACKAGE_FILE"

    upgrade_site
    verify_upgrade
    cleanup

    print_header "Upgrade Completato!"
    echo -e "${GREEN}CheckMK è stato aggiornato da $CURRENT_VERSION a $LATEST_VERSION${NC}"
    echo ""
    print_info "Backup disponibile in: $BACKUP_DIR"
    echo ""
}

main

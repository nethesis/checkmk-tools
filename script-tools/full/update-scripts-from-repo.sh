#!/usr/bin/env bash
#
# Script per aggiornare automaticamente gli script del sistema
# sostituendoli con le versioni "r*" presenti nel repository.
#
# Uso:
#   ./update-scripts-from-repo.sh [DIRECTORY_REPO] [SEARCH_PATH] [--auto]
#
# --auto: modalità automatica (scansione da / con prune).
# set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}
log_success() {
    echo -e "${GREEN}OK${NC} $1"
}
log_warning() {
    echo -e "${YELLOW}WARN${NC} $1"
}
log_error() {
    echo -e "${RED}ERR${NC} $1" >&2
}

REPO_DIR="${1:-/opt/checkmk-tools}"
AUTO_MODE=false

if [[ "$2" == "--auto" ]] || [[ "$3" == "--auto" ]]; then
    AUTO_MODE=true
    SEARCH_PATHS=("/")
else
    SEARCH_PATH="${2:-/opt/omd}"
    SEARCH_PATHS=("$SEARCH_PATH")
fi

BACKUP_DIR="/tmp/script-backup-$(date +%Y%m%d-%H%M%S)"

if [[ ! -d "$REPO_DIR" ]]; then
    log_error "Directory repository non trovata: $REPO_DIR"
    exit 1
fi

log "========================================"
log "UPDATE SCRIPT DA REPOSITORY"
log "========================================"
log "Repository: $REPO_DIR"

if $AUTO_MODE; then
    log "Modalità: AUTOMATICA (sistema completo)"
    log "Ricerca in: / (tutto il filesystem)"
    log ""
    log "ATTENZIONE: La scansione completa può richiedere alcuni minuti"
else
    log "Modalità: MANUALE"
    log "Ricerca in: ${SEARCH_PATHS[0]}"
fi
log ""

log "Aggiornamento repository..."
cd "$REPO_DIR" || exit 1

if ! git diff --quiet || ! git diff --cached --quiet; then
    log_warning "Modifiche locali rilevate, salvataggio temporaneo..."
    git stash push -m "Auto-stash before update $(date +%Y%m%d-%H%M%S)" >/dev/null 2>&1 || true
fi

git pull origin main 2>&1 | grep -v "Already up to date" || true
log_success "Repository aggiornato"
log ""

mkdir -p "$BACKUP_DIR"
log "Directory backup: $BACKUP_DIR"
log ""

UPDATED=0
SKIPPED=0
ERRORS=0
declare -A REPLACEMENTS

log "Scansione script nel sistema..."
log ""

find_targets() {
    local search_dir="$1"
    if [[ "$search_dir" == "/" ]]; then
        find / \
            \( -path /proc -o -path /sys -o -path /dev -o -path /run -o -path /tmp -o -path /var/tmp -o -path '*/snap' -o -path '*/.git' \) -prune -o \
            -type f \( -name "*.sh" -o -executable \) -print0 2>/dev/null
    else
        find "$search_dir" -type f \( -name "*.sh" -o -executable \) -print0 2>/dev/null
    fi
}

for search_dir in "${SEARCH_PATHS[@]}"; do
    if [[ ! -d "$search_dir" ]]; then
        log_warning "Directory non trovata, skip: $search_dir"
        continue
    fi

    log "Scansione: $search_dir"
    while IFS= read -r -d '' target_script; do
        local_name=$(basename "$target_script")
        local_dir=$(dirname "$target_script")

        if [[ "$local_name" =~ \.(backup|bak|old|tmp)$ ]] || [[ "$local_name" =~ ^\..*$ ]]; then
            ((SKIPPED++))
            continue
        fi
        if [[ "$local_name" =~ ^r.* ]]; then
            ((SKIPPED++))
            continue
        fi
        if [[ "$target_script" == "$REPO_DIR"* ]]; then
            continue
        fi

        repo_script=$(find "$REPO_DIR" -type f -name "r${local_name}" 2>/dev/null | head -1)
        if [[ -z "$repo_script" ]] || [[ ! -f "$repo_script" ]]; then
            continue
        fi

        log "Trovato: ${YELLOW}$local_dir/$local_name${NC}"
        log "      -> ${GREEN}$(basename "$(dirname "$repo_script")")/r${local_name}${NC}"

        backup_path="$BACKUP_DIR${local_dir}"
        mkdir -p "$backup_path"
        cp -a "$target_script" "$backup_path/" 2>/dev/null || true

        original_owner=$(stat -c '%U:%G' "$target_script" 2>/dev/null || echo "root:root")

        if bash -n "$repo_script" >/dev/null 2>&1 || [[ -x "$repo_script" ]]; then
            cp -a "$repo_script" "$target_script"
            chmod +x "$target_script" 2>/dev/null || true
            chown "$original_owner" "$target_script" 2>/dev/null || true

            log_success "Aggiornato: $local_dir/$local_name"
            REPLACEMENTS["$target_script"]="r${local_name}"
            ((UPDATED++))
        else
            log_error "Errore sintassi in r${local_name}, skip"
            ((ERRORS++))
        fi
    done < <(find_targets "$search_dir")
done

log ""
log "========================================"
log "RIEPILOGO AGGIORNAMENTO"
log "========================================"
log_success "Aggiornati: $UPDATED script"
log_warning "Trovati ma non aggiornati: $SKIPPED script"
if [[ $ERRORS -gt 0 ]]; then
    log_error "Errori: $ERRORS script"
fi

log ""

if [[ $UPDATED -gt 0 ]]; then
    log "Script sostituiti:"
    for original in "${!REPLACEMENTS[@]}"; do
        echo "  - $original -> ${REPLACEMENTS[$original]}"
    done
    log ""

    log "========================================"
    log "VERIFICA FILE SOSTITUITI"
    log "========================================"
    log "Controllo presenza e integrità dei file aggiornati..."
    log ""

    verify_success=0
    verify_failed=0
    for original in "${!REPLACEMENTS[@]}"; do
        if [[ -f "$original" ]]; then
            if [[ -x "$original" ]]; then
                if head -1 "$original" 2>/dev/null | grep -q "bash"; then
                    if bash -n "$original" >/dev/null 2>&1; then
                        log_success "OK: $original (presente, eseguibile, sintassi valida)"
                        ((verify_success++))
                    else
                        log_error "ERRORE SINTASSI: $original"
                        ((verify_failed++))
                    fi
                else
                    log_success "OK: $original (presente, eseguibile)"
                    ((verify_success++))
                fi
            else
                log_warning "WARN: $original (presente ma non eseguibile)"
                ((verify_failed++))
            fi
        else
            log_error "MANCANTE: $original"
            ((verify_failed++))
        fi
    done

    log ""
    log "Verifica completata: ${verify_success} OK, ${verify_failed} problemi"
    log ""
    log "Backup salvato in: $BACKUP_DIR"
    log ""
    log_success "Aggiornamento completato!"
    log ""
    log "Per ripristinare il backup:"
    log "  cp -r $BACKUP_DIR/* /"
else
    log_warning "Nessuno script aggiornato"
    rm -rf "$BACKUP_DIR" 2>/dev/null || true
fi

log ""
exit 0

#!/usr/bin/env bash
set -euo pipefail

# update-all-scripts.sh
# Aggiorna SOLO i file gia' presenti sul sistema, copiandoli dal repository.
# Non aggiunge nuovi file: se nel sistema un nome non esiste, non viene creato.
# Output semplice (ASCII-only).

REPO_DIR="${1:-/opt/checkmk-tools}"
BACKUP_DIR="/tmp/scripts-backup-$(date +%Y%m%d-%H%M%S)"
UPDATED=0

die() { echo "[ERR] $*" >&2; exit 1; }
log() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "eseguire come root (sudo)"
[[ -d "$REPO_DIR" ]] || die "repository non trovato: $REPO_DIR"
command -v git >/dev/null 2>&1 || die "git non trovato"

mkdir -p "$BACKUP_DIR"
log "Repository: $REPO_DIR"
log "Backup: $BACKUP_DIR"

log "Aggiorno repository (git pull)..."
cd "$REPO_DIR"
if ! git diff --quiet || ! git diff --cached --quiet; then
    warn "Modifiche locali rilevate: eseguo git stash"
    git stash push -m "Auto-stash $(date +%Y%m%d-%H%M%S)" >/dev/null 2>&1 || true
fi
git pull --rebase --autostash origin main >/dev/null 2>&1 || git pull origin main >/dev/null 2>&1 || true

resolve_src_dir() {
    local rel="$1"
    if [[ -d "$REPO_DIR/$rel" ]]; then
        printf '%s' "$REPO_DIR/$rel"
        return 0
    fi
    if [[ -d "$REPO_DIR/$rel/full" ]]; then
        printf '%s' "$REPO_DIR/$rel/full"
        return 0
    fi
    return 1
}

update_existing_files() {
    local repo_rel="$1"
    local system_dir="$2"
    local label="$3"
    local src_dir
    local count=0

    if ! src_dir="$(resolve_src_dir "$repo_rel")"; then
        warn "$label: cartella repo non trovata: $repo_rel"
        return 0
    fi
    if [[ ! -d "$system_dir" ]]; then
        warn "$label: cartella sistema non trovata: $system_dir"
        return 0
    fi

    log "$label: aggiorno file esistenti in $system_dir"
    shopt -s nullglob
    for dest in "$system_dir"/*; do
        local name owner mode backup_path
        name="$(basename "$dest")"

        [[ -f "$dest" ]] || continue
        [[ "$name" =~ ^\. ]] && continue
        [[ "$name" =~ \.(md|backup|bak|old|tmp|disabled)$ ]] && continue

        if [[ -f "$src_dir/$name" ]]; then
            owner="$(stat -c '%u:%g' "$dest" 2>/dev/null || echo "0:0")"
            mode="$(stat -c '%a' "$dest" 2>/dev/null || echo "755")"

            backup_path="$BACKUP_DIR/$label"
            mkdir -p "$backup_path"
            cp -a "$dest" "$backup_path/" 2>/dev/null || true

            cp -a "$src_dir/$name" "$dest"
            chown "$owner" "$dest" 2>/dev/null || true
            chmod "$mode" "$dest" 2>/dev/null || true
            log "  updated: $name"
            ((count++))
        fi
    done

    if (( count > 0 )); then
        log "$label: aggiornati $count file"
        UPDATED=$((UPDATED + count))
    else
        warn "$label: nessun file da aggiornare"
    fi
}

# Destinazioni tipiche (se non esistono, vengono skippate)
update_existing_files "script-notify-checkmk" "/opt/omd/sites/monitoring/local/share/check_mk/notifications" "notifiche"
update_existing_files "script-check-ns7" "/usr/lib/check_mk_agent/plugins" "ns7-plugins"
update_existing_files "script-check-ns7" "/usr/lib/check_mk_agent/local" "ns7-local"
update_existing_files "script-check-ns8" "/usr/lib/check_mk_agent/plugins" "ns8-plugins"
update_existing_files "script-check-ns8" "/usr/lib/check_mk_agent/local" "ns8-local"
update_existing_files "script-check-ubuntu" "/usr/lib/check_mk_agent/plugins" "ubuntu-plugins"
update_existing_files "script-check-ubuntu" "/usr/lib/check_mk_agent/local" "ubuntu-local"
update_existing_files "script-check-proxmox" "/usr/lib/check_mk_agent/plugins" "proxmox-plugins"
update_existing_files "script-check-proxmox" "/usr/lib/check_mk_agent/local" "proxmox-local"
update_existing_files "script-tools/full" "/opt/omd/sites/monitoring/local/bin" "tools"
update_existing_files "Ydea-Toolkit" "/opt/ydea-toolkit" "ydea-toolkit"

log "Totale file aggiornati: $UPDATED"
log "Backup salvato in: $BACKUP_DIR"
log "Ripristino: cp -a $BACKUP_DIR/* /"
exit 0

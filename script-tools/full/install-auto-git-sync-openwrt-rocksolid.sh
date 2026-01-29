#!/bin/sh
# ==========================================================
#  Auto Git Sync per NethSecurity/OpenWrt - ROCKSOLID
#  Versione semplificata per sistemi senza systemd
#  Usa cron invece di systemd service
# ==========================================================

set -e

SYSUPGRADE_CONF="/etc/sysupgrade.conf"
REPO_DIR="/opt/checkmk-tools"
REPO_URL="https://github.com/Coverup20/checkmk-tools.git"
SYNC_SCRIPT="/usr/local/bin/git-auto-sync.sh"
CRON_FILE="/etc/crontabs/root"

log() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
error() { echo "[ERROR] $*" >&2; }
die() { error "$*"; exit 1; }

# ============================================================================
# ROCKSOLID: Funzione per aggiungere file a sysupgrade.conf
# ============================================================================
add_to_sysupgrade() {
    local file_path="$1"
    local comment="${2:-}"
    
    if [ ! -f "$SYSUPGRADE_CONF" ]; then
        log "Creo $SYSUPGRADE_CONF"
        cat > "$SYSUPGRADE_CONF" <<'EOF'
## This file contains files and directories that should
## be preserved during an upgrade.

EOF
    fi
    
    if grep -qxF "$file_path" "$SYSUPGRADE_CONF" 2>/dev/null; then
        return 0
    fi
    
    if [ -n "$comment" ]; then
        echo "" >> "$SYSUPGRADE_CONF"
        echo "# $comment" >> "$SYSUPGRADE_CONF"
    fi
    
    echo "$file_path" >> "$SYSUPGRADE_CONF"
    log "Protetto: $file_path"
}

# ============================================================================
# Banner
# ============================================================================
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Auto Git Sync - ROCKSOLID Edition (OpenWrt/NethSecurity)     ║"
echo "║  Versione con cron + protezione sysupgrade.conf               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Root check
if [ "$(id -u)" -ne 0 ]; then
    die "Questo script deve essere eseguito come root"
fi
log "Esecuzione come root: OK"

# ============================================================================
# Installa Git
# ============================================================================
if ! command -v git >/dev/null 2>&1; then
    log "Git non trovato, installazione in corso..."
    if command -v opkg >/dev/null 2>&1; then
        opkg update
        opkg install git git-http
        log "Git installato via opkg"
    else
        die "opkg non trovato, impossibile installare git"
    fi
else
    log "Git già installato: $(git --version)"
fi

# ============================================================================
# Clona Repository
# ============================================================================
if [ -d "$REPO_DIR/.git" ]; then
    log "Repository già presente in $REPO_DIR"
    cd "$REPO_DIR" || die "cd fallito"
    
    # Test git pull
    log "Test git pull..."
    if git pull 2>&1; then
        log "Repository aggiornato"
    else
        warn "Git pull fallito, continuo comunque"
    fi
else
    log "Clonazione repository in $REPO_DIR..."
    mkdir -p "$(dirname "$REPO_DIR")"
    
    if ! git clone "$REPO_URL" "$REPO_DIR" 2>&1; then
        die "Clonazione fallita"
    fi
    
    log "Repository clonato con successo"
fi

# ============================================================================
# Crea Script di Sync
# ============================================================================
log "Creazione script di sync: $SYNC_SCRIPT"

cat > "$SYNC_SCRIPT" <<'SYNCSCRIPT'
#!/bin/sh
# Auto Git Sync Worker Script
# Eseguito da cron ogni minuto

REPO_DIR="/opt/checkmk-tools"
LOG_FILE="/var/log/auto-git-sync.log"
MAX_LOG_SIZE=1048576  # 1MB

# Rotazione log se troppo grande
if [ -f "$LOG_FILE" ] && [ "$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)" -gt "$MAX_LOG_SIZE" ]; then
    mv "$LOG_FILE" "$LOG_FILE.old" 2>/dev/null || true
fi

# Timestamp
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Auto sync started" >> "$LOG_FILE"

# Verifica repository
if [ ! -d "$REPO_DIR/.git" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Repository not found" >> "$LOG_FILE"
    exit 1
fi

cd "$REPO_DIR" || exit 1

# Git pull
if git pull origin main >> "$LOG_FILE" 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sync completed" >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Git pull failed" >> "$LOG_FILE"
fi
SYNCSCRIPT

chmod +x "$SYNC_SCRIPT"
log "Script di sync creato"

# ============================================================================
# Configura Cron
# ============================================================================
log "Configurazione cron job..."

# Rimuovi vecchie entry (se esistono)
if [ -f "$CRON_FILE" ]; then
    sed -i '/git-auto-sync\.sh/d' "$CRON_FILE"
fi

# Aggiungi nuovo cron job (ogni minuto)
echo "* * * * * $SYNC_SCRIPT" >> "$CRON_FILE"
log "Cron job aggiunto (esecuzione ogni minuto)"

# Riavvia cron
if /etc/init.d/cron restart 2>/dev/null; then
    log "Cron riavviato"
else
    warn "Impossibile riavviare cron, potrebbe essere necessario riavvio manuale"
fi

# ============================================================================
# ROCKSOLID: Proteggi Installazione
# ============================================================================
echo ""
echo "========================================="
echo "  ROCKSOLID: Protezione Installazione"
echo "========================================="
echo ""

add_to_sysupgrade "$REPO_DIR/" "CheckMK Tools Repository (Git Sync)"
add_to_sysupgrade "$SYNC_SCRIPT" "Git Auto Sync Script"
add_to_sysupgrade "$CRON_FILE" "Cron Jobs (include git sync)"
add_to_sysupgrade "/var/log/auto-git-sync.log" "Git Sync Log File"

# ============================================================================
# Crea Script Post-Upgrade
# ============================================================================
POST_UPGRADE="/etc/git-sync-post-upgrade.sh"
log "Creazione script post-upgrade: $POST_UPGRADE"

cat > "$POST_UPGRADE" <<'POSTUPGRADE'
#!/bin/sh
# Post-upgrade verification per Git Auto Sync

log() { logger -t git-sync-post-upgrade "$*"; echo "[POST-UPGRADE] $*"; }

log "Verifica Git Auto Sync post-upgrade"

# Verifica script sync
if [ ! -x /usr/local/bin/git-auto-sync.sh ]; then
    log "ERRORE: Script sync mancante!"
    exit 1
fi

# Verifica repository
if [ ! -d /opt/checkmk-tools/.git ]; then
    log "WARN: Repository mancante, potrebbe essere necessario reclonare"
fi

# Verifica cron job
if ! grep -q 'git-auto-sync.sh' /etc/crontabs/root 2>/dev/null; then
    log "WARN: Cron job mancante, aggiungo..."
    echo "* * * * * /usr/local/bin/git-auto-sync.sh" >> /etc/crontabs/root
    /etc/init.d/cron restart 2>/dev/null || true
fi

# Riavvia cron
log "Riavvio cron"
/etc/init.d/cron restart 2>/dev/null || true

log "Verifica completata"
POSTUPGRADE

chmod +x "$POST_UPGRADE"
add_to_sysupgrade "$POST_UPGRADE" "Git Sync Post-Upgrade Script"

# ============================================================================
# Test Immediato
# ============================================================================
echo ""
log "Esecuzione test sync..."
if "$SYNC_SCRIPT"; then
    log "Test sync completato con successo"
else
    warn "Test sync fallito, verifica log in /var/log/auto-git-sync.log"
fi

# ============================================================================
# Riepilogo
# ============================================================================
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  INSTALLAZIONE COMPLETATA - ROCKSOLID MODE ATTIVO             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Configurazione:"
echo "  ✓ Repository: $REPO_DIR"
echo "  ✓ Script sync: $SYNC_SCRIPT"
echo "  ✓ Frequenza: Ogni 1 minuto (cron)"
echo "  ✓ Log: /var/log/auto-git-sync.log"
echo ""
echo "Protezioni ROCKSOLID attivate:"
echo "  ✓ File critici aggiunti a $SYSUPGRADE_CONF"
echo "  ✓ Script post-upgrade: $POST_UPGRADE"
echo "  ✓ Resistente ai major upgrade"
echo ""
echo "Comandi utili:"
echo ""
echo "  - Log in tempo reale:"
echo "    tail -f /var/log/auto-git-sync.log"
echo ""
echo "  - Sync manuale:"
echo "    $SYNC_SCRIPT"
echo ""
echo "  - Disabilita sync:"
echo "    sed -i '/git-auto-sync\.sh/d' $CRON_FILE"
echo "    /etc/init.d/cron restart"
echo ""
echo "  - Post-upgrade verification:"
echo "    $POST_UPGRADE"
echo ""
echo "File protetti (sysupgrade.conf):"
grep -E 'checkmk-tools|git-auto-sync|git-sync-post-upgrade' "$SYSUPGRADE_CONF" 2>/dev/null || echo "  (verifica manualmente)"
echo ""
echo "IMPORTANTE: Dopo un major upgrade, esegui:"
echo "  $POST_UPGRADE"
echo ""
echo "========================================="

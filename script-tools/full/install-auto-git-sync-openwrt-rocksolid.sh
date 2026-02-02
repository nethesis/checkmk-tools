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
add_to_sysupgrade "/usr/local/bin/" "Script Custom Directory (preserva tutti gli script)"
add_to_sysupgrade "/usr/lib/check_mk_agent/local/" "CheckMK Agent Local Checks"

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

# ==========================================================
# FASE 0: RIPRISTINA BINARI CRITICI (se disponibili)
# ==========================================================
BACKUP_DIR="/opt/checkmk-tools/BACKUP-BINARIES"

if [ -d "$BACKUP_DIR" ]; then
    log "Ripristino binari critici da backup (se necessario)..."
    
    for backup in "$BACKUP_DIR"/*.backup; do
        [ -f "$backup" ] || continue
        
        basename_file=$(basename "$backup" .backup)
        
        case "$basename_file" in
            tar-gnu|gzip-gnu|gunzip-gnu|zcat-gnu)
                dest="/usr/libexec/$basename_file"
                ;;
            ar)
                dest="/usr/bin/$basename_file"
                ;;
            libbfd-*.so)
                dest="/usr/lib/$basename_file"
                ;;
            *)
                continue
                ;;
        esac
        
        # Ripristina se mancante o corrotto
        if [ ! -f "$dest" ]; then
            log "  ⚠ MANCANTE: $dest - ripristino da backup"
            cp -p "$backup" "$dest" 2>/dev/null && log "  ✓ RIPRISTINATO: $dest"
        elif ! file "$dest" 2>/dev/null | grep -q "ELF"; then
            log "  ⚠ CORROTTO: $dest - ripristino da backup"
            cp -p "$backup" "$dest" 2>/dev/null && log "  ✓ RIPRISTINATO: $dest"
        fi
    done
fi

# ==========================================================
# FASE 1: VERIFICA GIT AUTO SYNC
# ==========================================================
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
# ROCKSOLID: Ripristina Binari Critici (se backup disponibile)
# ============================================================================
restore_critical_binaries() {
    local BACKUP_DIR="/opt/checkmk-tools/BACKUP-BINARIES"
    
    [ -d "$BACKUP_DIR" ] || return 0
    
    log "Verifico e ripristino binari critici da backup (se necessario)..."
    
    for backup in "$BACKUP_DIR"/*.backup; do
        [ -f "$backup" ] || continue
        
        basename_file=$(basename "$backup" .backup)
        
        case "$basename_file" in
            tar-gnu|gzip-gnu|gunzip-gnu|zcat-gnu)
                dest="/usr/libexec/$basename_file"
                ;;
            ar)
                dest="/usr/bin/$basename_file"
                ;;
            libbfd-*.so)
                dest="/usr/lib/$basename_file"
                ;;
            *)
                continue
                ;;
        esac
        
        # Ripristina se mancante o corrotto
        if [ ! -f "$dest" ] || ! file "$dest" 2>/dev/null | grep -q "ELF"; then
            log "  → Ripristino: $dest"
            cp -p "$backup" "$dest" 2>/dev/null || true
        fi
    done
}

# ============================================================================
# ROCKSOLID: Installa Autocheck all'Avvio
# ============================================================================
echo ""
log "Installazione script autocheck all'avvio..."

AUTOCHECK_SCRIPT="/usr/local/bin/rocksolid-startup-check.sh"
AUTOCHECK_LOG="/var/log/rocksolid-startup.log"

cat > "$AUTOCHECK_SCRIPT" <<'AUTOCHECK_EOF'
#!/bin/sh
# ==========================================================
# ROCKSOLID Startup Check & Remediation
# Verifica e ripristina servizi critici ad ogni avvio
# ==========================================================

LOG_FILE="/var/log/rocksolid-startup.log"
SYSUPGRADE_CONF="/etc/sysupgrade.conf"

# Funzione log con timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
    logger -t rocksolid-startup "$*"
}

log "========================================="
log "ROCKSOLID Startup Check - AVVIO"
log "========================================="

# ============================================================================
# 0. RIPRISTINA BINARI CRITICI (se backup disponibile)
# ============================================================================
BACKUP_DIR="/opt/checkmk-tools/BACKUP-BINARIES"

if [ -d "$BACKUP_DIR" ]; then
    log "[Binari Critici] Verifica e ripristino in corso..."
    
    for backup in "$BACKUP_DIR"/*.backup; do
        [ -f "$backup" ] || continue
        
        basename_file=$(basename "$backup" .backup)
        
        case "$basename_file" in
            tar-gnu|gzip-gnu|gunzip-gnu|zcat-gnu)
                dest="/usr/libexec/$basename_file"
                ;;
            ar)
                dest="/usr/bin/$basename_file"
                ;;
            libbfd-*.so)
                dest="/usr/lib/$basename_file"
                ;;
            *)
                continue
                ;;
        esac
        
        # Ripristina se mancante o corrotto
        if [ ! -f "$dest" ]; then
            log "[Binari Critici] RIPRISTINO: $dest (mancante)"
            cp -p "$backup" "$dest" 2>/dev/null || true
        elif ! file "$dest" 2>/dev/null | grep -q "ELF"; then
            log "[Binari Critici] RIPRISTINO: $dest (corrotto)"
            cp -p "$backup" "$dest" 2>/dev/null || true
        fi
    done
    
    log "[Binari Critici] Verifica completata"
fi

# ============================================================================
# 1. VERIFICA E RIPRISTINA CHECKMK AGENT
# ============================================================================
log "[CheckMK Agent] Verifica in corso..."

if [ ! -x /usr/bin/check_mk_agent ]; then
    log "[CheckMK Agent] ERRORE: Binary mancante!"
    log "[CheckMK Agent] Eseguo script post-upgrade..."
    if [ -x /etc/checkmk-post-upgrade.sh ]; then
        /etc/checkmk-post-upgrade.sh >> "$LOG_FILE" 2>&1
    else
        log "[CheckMK Agent] CRITICO: Script post-upgrade mancante!"
    fi
else
    # Binary presente, verifica servizio
    if ! pgrep -f "socat TCP-LISTEN:6556" >/dev/null 2>&1; then
        log "[CheckMK Agent] Servizio non attivo, avvio..."
        /etc/init.d/check_mk_agent enable 2>/dev/null || true
        /etc/init.d/check_mk_agent restart 2>/dev/null || true
        sleep 2
        if pgrep -f "socat TCP-LISTEN:6556" >/dev/null 2>&1; then
            log "[CheckMK Agent] Servizio riavviato con successo"
        else
            log "[CheckMK Agent] ERRORE: Impossibile avviare servizio"
        fi
    else
        log "[CheckMK Agent] OK - Servizio attivo"
    fi
fi

# ============================================================================
# 2. VERIFICA E RIPRISTINA FRP CLIENT
# ============================================================================
log "[FRP Client] Verifica in corso..."

if [ -x /usr/local/bin/frpc ] && [ -f /etc/frp/frpc.toml ]; then
    if ! pgrep -f frpc >/dev/null 2>&1; then
        log "[FRP Client] Servizio non attivo, avvio..."
        /etc/init.d/frpc enable 2>/dev/null || true
        /etc/init.d/frpc restart 2>/dev/null || true
        sleep 2
        if pgrep -f frpc >/dev/null 2>&1; then
            log "[FRP Client] Servizio riavviato con successo"
        else
            log "[FRP Client] ERRORE: Impossibile avviare servizio"
        fi
    else
        log "[FRP Client] OK - Servizio attivo"
    fi
else
    log "[FRP Client] Non configurato o mancante (opzionale)"
fi

# ============================================================================
# 3. VERIFICA E INSTALLA GIT (SE MANCANTE)
# ============================================================================
log "[Git] Verifica in corso..."

if ! command -v git >/dev/null 2>&1; then
    log "[Git] MANCANTE - Installazione automatica..."
    
    if command -v opkg >/dev/null 2>&1; then
        log "[Git] Aggiornamento repository opkg..."
        opkg update >> "$LOG_FILE" 2>&1
        
        log "[Git] Installazione git + git-http..."
        if opkg install git git-http >> "$LOG_FILE" 2>&1; then
            log "[Git] Installato con successo: $(git --version 2>/dev/null || echo 'versione sconosciuta')"
        else
            log "[Git] ERRORE: Installazione fallita"
        fi
    else
        log "[Git] ERRORE: opkg non disponibile"
    fi
else
    log "[Git] OK - Presente: $(git --version)"
fi

# ============================================================================
# 4. VERIFICA GIT AUTO-SYNC
# ============================================================================
log "[Git Auto-Sync] Verifica in corso..."

if [ -x /usr/local/bin/git-auto-sync.sh ]; then
    # Verifica cron job
    if grep -q 'git-auto-sync.sh' /etc/crontabs/root 2>/dev/null; then
        log "[Git Auto-Sync] OK - Cron job configurato"
        
        # Test sync se git disponibile
        if command -v git >/dev/null 2>&1 && [ -d /opt/checkmk-tools/.git ]; then
            log "[Git Auto-Sync] Test sync manuale..."
            /usr/local/bin/git-auto-sync.sh >> "$LOG_FILE" 2>&1
            log "[Git Auto-Sync] Sync completato"
        fi
    else
        log "[Git Auto-Sync] WARN: Cron job mancante, ripristino..."
        if [ -x /etc/git-sync-post-upgrade.sh ]; then
            /etc/git-sync-post-upgrade.sh >> "$LOG_FILE" 2>&1
        else
            # Aggiungi manualmente
            echo "* * * * * /usr/local/bin/git-auto-sync.sh" >> /etc/crontabs/root
            /etc/init.d/cron restart 2>/dev/null || true
            log "[Git Auto-Sync] Cron job ripristinato"
        fi
    fi
else
    log "[Git Auto-Sync] Non configurato (opzionale)"
fi

# ============================================================================
# 5. VERIFICA REPOSITORY CHECKMK-TOOLS
# ============================================================================
log "[Repository] Verifica in corso..."

if [ -d /opt/checkmk-tools/.git ]; then
    log "[Repository] OK - Presente in /opt/checkmk-tools"
else
    log "[Repository] WARN: Repository non trovato in /opt/checkmk-tools"
fi

# ============================================================================
# 6. VERIFICA DIRECTORY CRITICHE
# ============================================================================
log "[Directory Critiche] Verifica presenza..."

# Verifica /usr/local/bin
if [ -d /usr/local/bin ]; then
    SCRIPT_COUNT=$(find /usr/local/bin -maxdepth 1 -type f -executable 2>/dev/null | wc -l)
    log "[Directory Critiche] /usr/local/bin: OK ($SCRIPT_COUNT script trovati)"
else
    log "[Directory Critiche] WARN: /usr/local/bin mancante"
fi

# Verifica /usr/lib/check_mk_agent/local
if [ -d /usr/lib/check_mk_agent/local ]; then
    LOCAL_CHECKS=$(find /usr/lib/check_mk_agent/local -maxdepth 1 -type f -executable 2>/dev/null | wc -l)
    log "[Directory Critiche] /usr/lib/check_mk_agent/local: OK ($LOCAL_CHECKS checks trovati)"
else
    log "[Directory Critiche] WARN: /usr/lib/check_mk_agent/local mancante"
fi

# ============================================================================
# 7. VERIFICA PROTEZIONI SYSUPGRADE.CONF
# ============================================================================
log "[Protezioni] Verifica sysupgrade.conf..."

PROTECTED_COUNT=$(grep -c -E 'check_mk|frpc|checkmk-tools|git-auto-sync|usr/local/bin' "$SYSUPGRADE_CONF" 2>/dev/null || echo "0")
log "[Protezioni] File protetti: $PROTECTED_COUNT"

if [ "$PROTECTED_COUNT" -lt 7 ]; then
    log "[Protezioni] WARN: Poche protezioni attive (attese almeno 7)"
fi

# ============================================================================
# 8. RIEPILOGO FINALE
# ============================================================================
log "========================================="
log "RIEPILOGO STATO SERVIZI:"
log "========================================="

# CheckMK Agent
if pgrep -f "socat TCP-LISTEN:6556" >/dev/null 2>&1; then
    log "  CheckMK Agent:  [OK]"
else
    log "  CheckMK Agent:  [FAIL]"
fi

# FRP Client
if pgrep -f frpc >/dev/null 2>&1; then
    log "  FRP Client:     [OK]"
else
    log "  FRP Client:     [N/A]"
fi

# Git
if command -v git >/dev/null 2>&1; then
    log "  Git:            [OK]"
else
    log "  Git:            [FAIL]"
fi

# Git Sync
if [ -x /usr/local/bin/git-auto-sync.sh ]; then
    log "  Git Auto-Sync:  [OK]"
else
    log "  Git Auto-Sync:  [N/A]"
fi

log "========================================="
log "ROCKSOLID Startup Check - COMPLETATO"
log "========================================="

exit 0
AUTOCHECK_EOF

chmod +x "$AUTOCHECK_SCRIPT"
log "Script autocheck creato: $AUTOCHECK_SCRIPT"

# Configura rc.local per esecuzione all'avvio
RC_LOCAL="/etc/rc.local"
if [ ! -f "$RC_LOCAL" ]; then
    log "Creo $RC_LOCAL"
    cat > "$RC_LOCAL" <<'RCLOCAL'
#!/bin/sh
# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.

exit 0
RCLOCAL
    chmod +x "$RC_LOCAL"
fi

# Aggiungi autocheck a rc.local se non presente
if ! grep -q 'rocksolid-startup-check.sh' "$RC_LOCAL"; then
    log "Aggiungo autocheck a rc.local"
    # Rimuovi exit 0 temporaneamente
    sed -i '/^exit 0/d' "$RC_LOCAL"
    # Aggiungi script e exit 0
    echo "$AUTOCHECK_SCRIPT &" >> "$RC_LOCAL"
    echo "exit 0" >> "$RC_LOCAL"
    log "Autocheck configurato per esecuzione all'avvio"
else
    log "Autocheck già presente in rc.local"
fi

# Proteggi file autocheck in sysupgrade.conf
add_to_sysupgrade "$AUTOCHECK_SCRIPT" "ROCKSOLID Startup Autocheck Script"
add_to_sysupgrade "$RC_LOCAL" "Boot Script (rc.local)"
add_to_sysupgrade "$AUTOCHECK_LOG" "ROCKSOLID Autocheck Log"

log "Autocheck installato e protetto"

# ============================================================================
# Test Immediato
# ============================================================================
echo ""
log "Ripristino binari critici (se necessario)..."
restore_critical_binaries

echo ""
log "Esecuzione test sync..."
if "$SYNC_SCRIPT"; then
    log "Test sync completato con successo"
else
    warn "Test sync fallito, verifica log in /var/log/auto-git-sync.log"
fi

echo ""
log "Esecuzione test autocheck..."
if "$AUTOCHECK_SCRIPT"; then
    log "Test autocheck completato - verifica log in $AUTOCHECK_LOG"
else
    warn "Test autocheck fallito"
fi

# ============================================================================
# Riepilogo
# ============================================================================
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  INSTALLAZIONE COMPLETATA - ROCKSOLID MODE ATTIVO             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Configurazione Git Sync:"
echo "  ✓ Repository: $REPO_DIR"
echo "  ✓ Script sync: $SYNC_SCRIPT"
echo "  ✓ Frequenza: Ogni 1 minuto (cron)"
echo "  ✓ Log sync: /var/log/auto-git-sync.log"
echo ""
echo "Autocheck all'Avvio:"
echo "  ✓ Script: $AUTOCHECK_SCRIPT"
echo "  ✓ Trigger: $RC_LOCAL (esecuzione automatica)"
echo "  ✓ Log autocheck: $AUTOCHECK_LOG"
echo "  ✓ Funzioni:"
echo "      - Verifica e riavvia CheckMK Agent"
echo "      - Verifica e riavvia FRP Client"
echo "      - Reinstalla Git se mancante (post-upgrade)"
echo "      - Ripristina cron git-sync"
echo "      - Test sync repository"
echo ""
echo "Protezioni ROCKSOLID attivate:"
echo "  ✓ File critici aggiunti a $SYSUPGRADE_CONF"
echo "  ✓ Script post-upgrade: $POST_UPGRADE"
echo "  ✓ Script autocheck: $AUTOCHECK_SCRIPT"
echo "  ✓ Directory protette:"
echo "      - /usr/local/bin/ (script custom)"
echo "      - /usr/lib/check_mk_agent/local/ (local checks)"
echo "  ✓ Resistente ai major upgrade"
echo ""
echo "Comandi utili:"
echo ""
echo "  - Log sync in tempo reale:"
echo "    tail -f /var/log/auto-git-sync.log"
echo ""
echo "  - Log autocheck:"
echo "    tail -f $AUTOCHECK_LOG"
echo ""
echo "  - Sync manuale:"
echo "    $SYNC_SCRIPT"
echo ""
echo "  - Test autocheck manuale:"
echo "    $AUTOCHECK_SCRIPT"
echo ""
echo "  - Disabilita sync:"
echo "    sed -i '/git-auto-sync\.sh/d' $CRON_FILE"
echo "    /etc/init.d/cron restart"
echo ""
echo "  - Post-upgrade verification:"
echo "    $POST_UPGRADE"
echo ""
echo "File protetti (sysupgrade.conf):"
grep -E 'checkmk-tools|git-auto-sync|git-sync-post-upgrade|rocksolid-startup-check|rc.local|usr/local/bin|check_mk_agent/local' "$SYSUPGRADE_CONF" 2>/dev/null | sed 's/^/  /' || echo "  (verifica manualmente)"
echo ""
echo "⚠️  IMPORTANTE POST-UPGRADE:"
echo "    Il sistema si auto-ripristina al riavvio grazie a:"
echo "    - $AUTOCHECK_SCRIPT (eseguito da rc.local)"
echo "    - Git viene reinstallato automaticamente se mancante"
echo "    - Tutti i servizi vengono riavviati automaticamente"
echo ""
echo "    Opzionale: Esegui manualmente dopo upgrade:"
echo "      $POST_UPGRADE"
echo ""
echo "========================================="

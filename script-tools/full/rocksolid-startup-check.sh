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
# 0. VERIFICA E RIPARA REPOSITORY OPKG
# ============================================================================
log "[Repository] Verifica repository opkg..."

if command -v opkg >/dev/null 2>&1; then
    # Controlla se repository sono corrotti
    REPO_STATUS=$(opkg list 2>&1 | grep -c "parse_from_stream_nomalloc" || echo 0)
    
    if [ "$REPO_STATUS" -gt 0 ]; then
        log "[Repository] CORRUZIONE rilevata - riparo repository"
        
        # Backup e pulizia cache corrotta
        rm -rf /var/opkg-lists/*.sig 2>/dev/null || true
        
        # Configura repository affidabili
        log "[Repository] Configuro repository OpenWrt base..."
        
        # Assicura che customfeeds.conf esista
        CUSTOMFEEDS="/etc/opkg/customfeeds.conf"
        if [ ! -f "$CUSTOMFEEDS" ]; then
            touch "$CUSTOMFEEDS"
        fi
        
        # Repository OpenWrt stabili (evita NethSecurity corrotti post-upgrade)
        grep -q "openwrt_packages" "$CUSTOMFEEDS" 2>/dev/null || \
            echo "src/gz openwrt_packages https://downloads.openwrt.org/releases/23.05.0/packages/x86_64/packages" >> "$CUSTOMFEEDS"
        
        grep -q "openwrt_base" "$CUSTOMFEEDS" 2>/dev/null || \
            echo "src/gz openwrt_base https://downloads.openwrt.org/releases/23.05.0/packages/x86_64/base" >> "$CUSTOMFEEDS"
        
        # Update repository
        log "[Repository] Aggiornamento liste pacchetti..."
        opkg update >> "$LOG_FILE" 2>&1 || log "[Repository] WARNING: Alcuni repository hanno fallito"
        
        log "[Repository] Ripristino repository completato"
    else
        log "[Repository] OK - Repository funzionanti"
    fi
else
    log "[Repository] opkg non disponibile (sistema non OpenWrt)"
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
# 6. VERIFICA PROTEZIONI SYSUPGRADE.CONF
# ============================================================================
log "[Protezioni] Verifica sysupgrade.conf..."

PROTECTED_COUNT=$(grep -c -E 'check_mk|frpc|checkmk-tools|git-auto-sync' "$SYSUPGRADE_CONF" 2>/dev/null || echo "0")
log "[Protezioni] File protetti: $PROTECTED_COUNT"

if [ "$PROTECTED_COUNT" -lt 5 ]; then
    log "[Protezioni] WARN: Poche protezioni attive (attese almeno 5)"
fi

# ============================================================================
# 7. RIEPILOGO FINALE
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

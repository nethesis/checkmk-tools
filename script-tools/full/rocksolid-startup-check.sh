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
# 4. VERIFICA GIT (opzionale)
# ============================================================================
# NOTA: Git non più necessario - tutti gli script eseguiti via curl da GitHub
log "[Git] Verifica in corso..."

if command -v git >/dev/null 2>&1; then
    GIT_VERSION=$(git --version 2>/dev/null || echo "unknown")
    log "[Git] OK - Presente: $GIT_VERSION (opzionale)"
    GIT_STATUS="OK"
else
    log "[Git] Non installato (non necessario - script eseguiti via curl da GitHub)"
    GIT_STATUS="N/A"
fi

# ============================================================================
# 5. VERIFICA REPOSITORY CHECKMK-TOOLS
# ============================================================================
# NOTA: Repository locale non necessario - tutti gli script vengono eseguiti
# direttamente da GitHub tramite curl per evitare corruzione file locali
log "[Repository] Verifica directory backup..."

if [ -d /opt/checkmk-tools/BACKUP-BINARIES ]; then
    log "[Repository] OK - Directory backup binari presente"
else
    log "[Repository] WARN: Directory backup binari non trovata"
    mkdir -p /opt/checkmk-tools/BACKUP-BINARIES 2>/dev/null || true
fi

# ============================================================================
# 6. PULIZIA REPOSITORY CUSTOM (prevenzione conflitti aggiornamenti)
# ============================================================================
log "[Repository] Pulizia repository custom OpenWrt..."

CUSTOMFEEDS="/etc/opkg/customfeeds.conf"
if [ -f "$CUSTOMFEEDS" ]; then
    # Verifica se contiene repository OpenWrt custom
    if grep -q "downloads.openwrt.org" "$CUSTOMFEEDS" 2>/dev/null; then
        log "[Repository] WARN: Repository OpenWrt custom trovati - rimozione in corso"
        
        # Backup del file originale (se non esiste già)
        if [ ! -f "${CUSTOMFEEDS}.backup" ]; then
            cp "$CUSTOMFEEDS" "${CUSTOMFEEDS}.backup" 2>/dev/null || true
            log "[Repository] Backup originale salvato in ${CUSTOMFEEDS}.backup"
        fi
        
        # Svuota il file mantenendo solo header
        cat > "$CUSTOMFEEDS" << 'EOF'
# add your custom package feeds here
#
# src/gz example_feed_name http://www.example.com/path/to/files
#
# Repository custom OpenWrt rimossi automaticamente da ROCKSOLID
# per evitare conflitti con aggiornamenti NethSecurity ufficiali
EOF
        log "[Repository] OK - Repository custom rimossi (previene conflitti aggiornamenti)"
    else
        log "[Repository] OK - Nessun repository custom non autorizzato"
    fi
else
    log "[Repository] INFO: File customfeeds.conf non presente"
fi

# ============================================================================
# 7. VERIFICA PROTEZIONI SYSUPGRADE.CONF
# ============================================================================
log "[Protezioni] Verifica sysupgrade.conf..."

PROTECTED_COUNT=$(grep -c -E 'check_mk|frpc|checkmk-tools|git-auto-sync' "$SYSUPGRADE_CONF" 2>/dev/null || echo "0")
log "[Protezioni] File protetti: $PROTECTED_COUNT"

if [ "$PROTECTED_COUNT" -lt 5 ]; then
    log "[Protezioni] WARN: Poche protezioni attive (attese almeno 5)"
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
    log "  Git:            [$GIT_STATUS]"
else
    log "  Git:            [N/A]"
fi

log "========================================="
log "ROCKSOLID Startup Check - COMPLETATO"
log "========================================="

exit 0

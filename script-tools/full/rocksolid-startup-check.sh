#!/bin/sh
# ==========================================================
# ROCKSOLID Startup Check & Remediation
# Verifica e ripristina servizi critici ad ogni avvio
# ==========================================================

LOG_FILE="/var/log/rocksolid-startup.log"
SYSUPGRADE_CONF="/etc/sysupgrade.conf"

# Funzione log con timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
    logger -t rocksolid-startup "$*"
}

log "========================================="
log "ROCKSOLID Startup Check - AVVIO"
log "========================================="

# ============================================================================
# 0. RIPRISTINA BINARI CRITICI (se backup disponibile)
# ============================================================================
BACKUP_DIR="/opt/checkmk-backups/binaries"

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

FRP_MARKER="/opt/checkmk-tools/.frp-installed"

if [ -f "$FRP_MARKER" ]; then
    # FRP era installato, deve funzionare
    if [ ! -x /usr/local/bin/frpc ] || [ ! -f /etc/frp/frpc.toml ] || [ ! -f /etc/init.d/frpc ]; then
        log "[FRP Client] CRITICO: FRP era installato ma binario/config/init mancante!"
        log "[FRP Client] Reinstallazione automatica..."
        
        # Reinstalla FRP usando script esistente (modalit├á non-interattiva)
        if [ -x /opt/checkmk-tools/script-tools/full/install-checkmk-agent-debtools-frp-nsec8c-rocksolid.sh ]; then
            export NON_INTERACTIVE=1
            /opt/checkmk-tools/script-tools/full/install-checkmk-agent-debtools-frp-nsec8c-rocksolid.sh >> "$LOG_FILE" 2>&1
            log "[FRP Client] Reinstallazione completata"
        else
            log "[FRP Client] ERRORE: Script di installazione non disponibile"
        fi
    elif ! pgrep -f frpc >/dev/null 2>&1; then
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
    # FRP non era mai stato installato, ├¿ opzionale
    if [ -x /usr/local/bin/frpc ] && [ -f /etc/frp/frpc.toml ]; then
        log "[FRP Client] Trovato ma senza marker (installazione manuale?)"
        if ! pgrep -f frpc >/dev/null 2>&1; then
            log "[FRP Client] Avvio servizio..."
            /etc/init.d/frpc enable 2>/dev/null || true
            /etc/init.d/frpc restart 2>/dev/null || true
        fi
    else
        log "[FRP Client] Non installato (opzionale)"
    fi
fi

# ============================================================================
# 2.5 VERIFICA E RIPRISTINA QEMU GUEST AGENT (VM ONLY)
# ============================================================================
if [ -f "/usr/bin/qemu-ga" ]; then
    log "[QEMU-GA] Verifica in corso..."
    
    # Self-healing: riconfigura init script in base a device disponibile
    if [ -e "/dev/virtio-ports/org.qemu.guest_agent.0" ]; then
        # Proxmox con virtio-serial disponibile
        EXPECTED_MODE="virtio-serial"
        EXPECTED_PATH="/dev/virtio-ports/org.qemu.guest_agent.0"
    elif [ -e "/dev/vport2p1" ]; then
        # Proxmox con device vportXpY diretto
        EXPECTED_MODE="virtio-serial"
        EXPECTED_PATH="/dev/vport2p1"
    else
        # Fallback isa-serial
        EXPECTED_MODE="isa-serial"
        EXPECTED_PATH="/dev/ttyS0"
    fi
    
    # Verifica se init script ha configurazione corretta
    if ! grep -q "$EXPECTED_MODE" /etc/init.d/qemu-ga 2>/dev/null; then
        log "[QEMU-GA] Riconfigurazione init script per $EXPECTED_MODE..."
        cat > /etc/init.d/qemu-ga <<QEMU_INIT
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/qemu-ga -m $EXPECTED_MODE -p $EXPECTED_PATH
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}
QEMU_INIT
        chmod +x /etc/init.d/qemu-ga
        log "[QEMU-GA] Init script aggiornato per $EXPECTED_MODE"
    fi
    
    if ! pgrep qemu-ga >/dev/null 2>&1; then
        log "[QEMU-GA] Servizio non attivo, avvio..."
        /etc/init.d/qemu-ga enable 2>/dev/null || true
        /etc/init.d/qemu-ga restart 2>/dev/null || true
        sleep 2
        
        if pgrep qemu-ga >/dev/null 2>&1; then
            log "[QEMU-GA] Servizio riavviato con successo ($EXPECTED_MODE)"
        else
            log "[QEMU-GA] ERRORE: Impossibile avviare servizio"
        fi
    else
        log "[QEMU-GA] OK - Servizio attivo"
    fi
else
    log "[QEMU-GA] Non installato (opzionale, solo per VM)"
fi

# ============================================================================
# 3. VERIFICA PROTEZIONI SYSUPGRADE.CONF
# ============================================================================
log "[Protezioni] Verifica sysupgrade.conf..."

# Conta tutte le righe non-commento non-vuote che iniziano con / (protezioni totali)
# -a forza trattamento come testo (alcuni sistemi vedono sysupgrade.conf come binario)
PROTECTED_COUNT=$(grep -a -v '^#' "$SYSUPGRADE_CONF" 2>/dev/null | grep -a -v '^$' | grep -a -E '^/' | wc -l)
PROTECTED_COUNT=$(echo "$PROTECTED_COUNT" | tr -d ' \n')
log "[Protezioni] File protetti: $PROTECTED_COUNT"

if [ "$PROTECTED_COUNT" -lt 5 ] 2>/dev/null; then
    log "[Protezioni] WARN: Poche protezioni attive (attese almeno 5)"
fi

# ============================================================================
# 4. RIEPILOGO FINALE
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

# QEMU Guest Agent
if [ -f "/usr/bin/qemu-ga" ]; then
    if pgrep qemu-ga >/dev/null 2>&1; then
        log "  QEMU-GA:        [OK]"
    else
        log "  QEMU-GA:        [FAIL]"
    fi
fi

# Auto Git Sync (controlla sia script wrapper che comando diretto)
if [ -f "/etc/crontabs/root" ]; then
    if grep -qE "git-auto-sync\.sh|git.*checkmk-tools.*pull" /etc/crontabs/root 2>/dev/null; then
        log "  Auto Git Sync:  [OK]"
    else
        log "  Auto Git Sync:  [N/A]"
    fi
else
    log "  Auto Git Sync:  [N/A]"
fi

# Local Check Scripts
LOCAL_CHECK_COUNT=$(find /usr/lib/check_mk_agent/local/ -type f -name "check_*.sh" 2>/dev/null | wc -l)
LOCAL_CHECK_COUNT=$(echo "$LOCAL_CHECK_COUNT" | tr -d ' \n')
if [ "$LOCAL_CHECK_COUNT" -gt 0 ] 2>/dev/null; then
    log "  Local Checks:   [OK] ($LOCAL_CHECK_COUNT scripts)"
else
    log "  Local Checks:   [N/A]"
fi

log "========================================="
log "ROCKSOLID Startup Check - COMPLETATO"
log "========================================="

exit 0

#!/bin/sh
set -eu

# install-checkmk-agent-debtools-frp-nsec8c-rocksolid.sh
# ROCKSOLID VERSION - Resiste ai major upgrade di NethSecurity/OpenWrt
# Install / uninstall Checkmk agent + (opzionale) FRP client su OpenWrt / NethSecurity (init: procd).
# Output semplice (ASCII-only).

# Modalità non-interattiva (es. boot automatico)
NON_INTERACTIVE="${NON_INTERACTIVE:-0}"

CUSTOMFEEDS="${CUSTOMFEEDS:-/etc/opkg/customfeeds.conf}"
TMPDIR="${TMPDIR:-/tmp/checkmk-deb}"
SYSUPGRADE_CONF="${SYSUPGRADE_CONF:-/etc/sysupgrade.conf}"

# OpenWrt 23.05 x86_64 (come versione originale dello script)
REPO_BASE="${REPO_BASE:-https://downloads.openwrt.org/releases/23.05.0/packages/x86_64/base}"
REPO_PACKAGES="${REPO_PACKAGES:-https://downloads.openwrt.org/releases/23.05.0/packages/x86_64/packages}"

# Configurazione CheckMK Server
CMK_SERVER="${CMK_SERVER:-monitor.nethlab.it}"
CMK_SITE="${CMK_SITE:-monitoring}"
CMK_PROTOCOL="${CMK_PROTOCOL:-https}"

# URL del .deb dell'agente (rilevato automaticamente o override manuale)
DEB_URL="${DEB_URL:-}"

FRP_VER="${FRP_VER:-0.64.0}"
FRPC_BIN="${FRPC_BIN:-/usr/local/bin/frpc}"
FRPC_CONF="${FRPC_CONF:-/etc/frp/frpc.toml}"
FRPC_INIT="${FRPC_INIT:-/etc/init.d/frpc}"
FRPC_LOG="${FRPC_LOG:-/var/log/frpc.log}"

log() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
die() { echo "[ERR] $*" >&2; exit 1; }

is_root() {
    [ "$(id -u 2>/dev/null || echo 1)" -eq 0 ]
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "comando mancante: $1"
}

# Controlla se siamo in modalità interattiva
is_interactive() {
    [ "$NON_INTERACTIVE" -eq 0 ] && [ -t 0 ]
}

add_repo() {
    name="$1"
    url="$2"
    grep -q "$url" "$CUSTOMFEEDS" 2>/dev/null || echo "src/gz $name $url" >>"$CUSTOMFEEDS"
}

# ============================================================================
# Rileva versione CheckMK e costruisce URL .deb dinamicamente
# ============================================================================
detect_checkmk_agent_url() {
    if [ -n "$DEB_URL" ]; then
        log "URL .deb specificato manualmente: $DEB_URL"
        return 0
    fi
    
    log "Rilevamento automatico versione CheckMK da $CMK_SERVER..."
    
    # Prova a rilevare la versione dall'API o dalla pagina agents
    local version=""
    local base_url="${CMK_PROTOCOL}://${CMK_SERVER}/${CMK_SITE}/check_mk/agents"
    
    # Metodo 1: Cerca la versione dalla pagina agents
    if command -v wget >/dev/null 2>&1; then
        version=$(wget -qO- --no-check-certificate "$base_url/" 2>/dev/null | grep -oP 'check-mk-agent_\K[0-9]+\.[0-9]+\.[0-9]+p[0-9]+' | head -1)
    elif command -v curl >/dev/null 2>&1; then
        version=$(curl -fsSL --insecure "$base_url/" 2>/dev/null | grep -oP 'check-mk-agent_\K[0-9]+\.[0-9]+\.[0-9]+p[0-9]+' | head -1)
    fi
    
    # Metodo 2: Prova URL diretto standard
    if [ -z "$version" ]; then
        warn "Impossibile rilevare versione automaticamente, provo versione di default"
        # Prova a scaricare dalla directory agents standard
        local test_url="${base_url}/check-mk-agent_2.4.0p14-1_all.deb"
        if command -v wget >/dev/null 2>&1; then
            if wget --spider --no-check-certificate "$test_url" 2>/dev/null; then
                version="2.4.0p14"
            fi
        elif command -v curl >/dev/null 2>&1; then
            if curl -fsSL -I --insecure "$test_url" >/dev/null 2>&1; then
                version="2.4.0p14"
            fi
        fi
    fi
    
    if [ -n "$version" ]; then
        DEB_URL="${base_url}/check-mk-agent_${version}-1_all.deb"
        log "Versione rilevata: $version"
        log "URL .deb: $DEB_URL"
    else
        # Fallback: usa URL di default
        DEB_URL="${CMK_PROTOCOL}://${CMK_SERVER}/${CMK_SITE}/check_mk/agents/check-mk-agent_2.4.0p14-1_all.deb"
        warn "Versione non rilevata, uso fallback: $DEB_URL"
    fi
}

# ============================================================================
# ROCKSOLID: Funzione per aggiungere file a sysupgrade.conf
# ============================================================================
add_to_sysupgrade() {
    local file_path="$1"
    local comment="${2:-}"
    
    # Crea il file se non esiste
    if [ ! -f "$SYSUPGRADE_CONF" ]; then
        log "Creo $SYSUPGRADE_CONF"
        cat > "$SYSUPGRADE_CONF" <<'EOF'
## This file contains files and directories that should
## be preserved during an upgrade.

EOF
    fi
    
    # Controlla se il file è già presente
    if grep -qxF "$file_path" "$SYSUPGRADE_CONF" 2>/dev/null; then
        return 0
    fi
    
    # Aggiungi commento se fornito
    if [ -n "$comment" ]; then
        echo "" >> "$SYSUPGRADE_CONF"
        echo "# $comment" >> "$SYSUPGRADE_CONF"
    fi
    
    # Aggiungi il file
    echo "$file_path" >> "$SYSUPGRADE_CONF"
    log "Aggiunto a sysupgrade.conf: $file_path"
}

# ============================================================================
# ROCKSOLID: Proteggi installazione CheckMK Agent
# ============================================================================
protect_checkmk_installation() {
    log "ROCKSOLID: Proteggo installazione CheckMK da major upgrade"
    
    # File critici CheckMK Agent
    add_to_sysupgrade "/usr/bin/check_mk_agent" "CheckMK Agent - Binary"
    add_to_sysupgrade "/etc/init.d/check_mk_agent" "CheckMK Agent - Init Script"
    add_to_sysupgrade "/etc/check_mk/" "CheckMK Agent - Configuration"
    
    # Package dependencies (se installati via opkg, sono già protetti)
    # Ma aggiungiamo customfeeds per sicurezza
    add_to_sysupgrade "/etc/opkg/customfeeds.conf" "Custom package repositories"
    
    log "Installazione CheckMK protetta contro major upgrade"
}

# ============================================================================
# ROCKSOLID: Backup Binari Critici
# Backup di tar/ar/gzip che si corrompono durante major upgrade
# ============================================================================
backup_critical_binaries() {
    local backup_dir="/opt/checkmk-tools/BACKUP-BINARIES"
    local bins="/usr/libexec/tar-gnu /usr/bin/ar /usr/libexec/gzip-gnu /usr/libexec/gunzip-gnu /usr/lib/libbfd-2.40.so"
    
    log "ROCKSOLID: Backup binari critici (protegge da corruzione durante upgrade)..."
    mkdir -p "$backup_dir" 2>/dev/null || true
    
    for bin in $bins; do
        if [ -f "$bin" ] && file "$bin" 2>/dev/null | grep -q "ELF"; then
            local backup_file="$backup_dir/$(basename "$bin").backup"
            cp -p "$bin" "$backup_file" 2>/dev/null && \
                log "  ✓ Backup: $bin" || \
                warn "  ✗ Backup fallito: $bin"
        fi
    done
    
    # Proteggi backup in sysupgrade
    if ! grep -q "$backup_dir" "$SYSUPGRADE_CONF" 2>/dev/null; then
        {
            echo ""
            echo "# ROCKSOLID: Backup binari critici (tar, ar, gzip)"
            echo "$backup_dir/"
        } >> "$SYSUPGRADE_CONF"
        log "  ✓ Backup protetto in sysupgrade.conf"
    fi
    
    log "Binari critici backuppati in: $backup_dir"
}

# ============================================================================
# ROCKSOLID: Proteggi installazione FRP Client
# ============================================================================
protect_frp_installation() {
    log "ROCKSOLID: Proteggo installazione FRP da major upgrade"
    
    add_to_sysupgrade "/usr/local/bin/frpc" "FRP Client - Binary"
    add_to_sysupgrade "/etc/frp/frpc.toml" "FRP Client - Configuration (CRITICO: contiene token)"
    add_to_sysupgrade "/etc/init.d/frpc" "FRP Client - Init Script"
    add_to_sysupgrade "/opt/checkmk-tools/.frp-installed" "FRP Client - Marker file (autocheck detection)"
    
    log "Installazione FRP protetta contro major upgrade"
}

# ============================================================================
# ROCKSOLID: Crea script di ripristino post-upgrade
# ============================================================================
create_post_upgrade_script() {
    local script_path="/etc/checkmk-post-upgrade.sh"
    
    log "Creo script di ripristino post-upgrade: $script_path"
    
    cat > "$script_path" <<'POSTSCRIPT'
#!/bin/sh
# Script eseguito automaticamente dopo major upgrade
# Ripristina binari corrotti e servizi CheckMK

log() { logger -t checkmk-post-upgrade "$*"; echo "[POST-UPGRADE] $*"; }

log "=== POST-UPGRADE: Inizio ripristino ==="

# ==========================================================
# FASE 1: RIPRISTINA BINARI CRITICI (tar, ar, gzip)
# Major upgrade spesso corrompe questi binari
# ==========================================================
BACKUP_DIR="/opt/checkmk-tools/BACKUP-BINARIES"

if [ -d "$BACKUP_DIR" ]; then
    log "Ripristino binari critici da backup..."
    
    for backup in "$BACKUP_DIR"/*.backup; do
        [ -f "$backup" ] || continue
        
        # Estrai nome originale
        basename_file=$(basename "$backup" .backup)
        
        # Determina path destinazione
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
                log "  ? SKIP: $basename_file (path sconosciuto)"
                continue
                ;;
        esac
        
        # Verifica se destinazione è corrotta (non-ELF)
        if [ -f "$dest" ]; then
            if ! file "$dest" 2>/dev/null | grep -q "ELF"; then
                log "  ⚠ CORROTTO: $dest - ripristino da backup"
                cp -p "$backup" "$dest" 2>/dev/null && \
                    log "  ✓ RIPRISTINATO: $dest" || \
                    log "  ✗ ERRORE ripristino: $dest"
            else
                log "  ✓ OK: $dest (già valido)"
            fi
        else
            # File mancante, ripristina
            log "  ⚠ MANCANTE: $dest - ripristino da backup"
            cp -p "$backup" "$dest" 2>/dev/null && \
                log "  ✓ RIPRISTINATO: $dest" || \
                log "  ✗ ERRORE ripristino: $dest"
        fi
    done
else
    log "⚠ Backup binari non trovato in $BACKUP_DIR"
fi

# ==========================================================
# FASE 2: VERIFICA E RIPRISTINA CHECKMK AGENT
# ==========================================================
log "Verifica installazione CheckMK Agent post-upgrade"

# Verifica binario
if [ ! -x /usr/bin/check_mk_agent ]; then
    log "ERRORE: /usr/bin/check_mk_agent mancante dopo upgrade!"
    exit 1
fi

# Verifica init script
if [ ! -x /etc/init.d/check_mk_agent ]; then
    log "ERRORE: /etc/init.d/check_mk_agent mancante dopo upgrade!"
    exit 1
fi

# Riattiva servizio
/etc/init.d/check_mk_agent enable 2>/dev/null || true
/etc/init.d/check_mk_agent restart 2>/dev/null || true

# Verifica FRP se presente
if [ -x /etc/init.d/frpc ]; then
    log "Riattivo FRP client"
    /etc/init.d/frpc enable 2>/dev/null || true
    /etc/init.d/frpc restart 2>/dev/null || true
fi

# Verifica processo socat
sleep 2
if pgrep -f "socat TCP-LISTEN:6556" >/dev/null 2>&1; then
    log "CheckMK Agent attivo su porta 6556"
else
    log "WARN: socat non in esecuzione, riavvio servizio"
    /etc/init.d/check_mk_agent restart
fi

log "Verifica completata"
POSTSCRIPT

    chmod +x "$script_path"
    
    # Proteggi anche lo script stesso
    add_to_sysupgrade "$script_path" "Post-upgrade verification script"
    
    log "Script post-upgrade creato e protetto"
}

# ============================================================================
# ROCKSOLID: Installa script autocheck all'avvio
# ============================================================================
install_autocheck() {
    log "Installazione script autocheck all'avvio"
    
    local autocheck_script="/usr/local/bin/rocksolid-startup-check.sh"
    local autocheck_log="/var/log/rocksolid-startup.log"
    local rc_local="/etc/rc.local"
    
    cat > "$autocheck_script" <<'AUTOCHECK_EOF'
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

FRP_MARKER="/opt/checkmk-tools/.frp-installed"

if [ -f "$FRP_MARKER" ]; then
    # FRP era installato, deve funzionare
    if [ ! -x /usr/local/bin/frpc ] || [ ! -f /etc/frp/frpc.toml ] || [ ! -f /etc/init.d/frpc ]; then
        log "[FRP Client] CRITICO: FRP era installato ma binario/config/init mancante!"
        log "[FRP Client] Reinstallazione automatica..."
        
        # Reinstalla FRP usando script esistente (modalità non-interattiva)
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
    # FRP non era mai stato installato, è opzionale
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
# 3. VERIFICA PROTEZIONI SYSUPGRADE.CONF
# ============================================================================
log "[Protezioni] Verifica sysupgrade.conf..."

PROTECTED_COUNT=$(grep -c -E 'check_mk|frpc' "$SYSUPGRADE_CONF" 2>/dev/null || echo "0")
log "[Protezioni] File protetti: $PROTECTED_COUNT"

if [ "$PROTECTED_COUNT" -lt 3 ]; then
    log "[Protezioni] WARN: Poche protezioni attive (attese almeno 3)"
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

log "========================================="
log "ROCKSOLID Startup Check - COMPLETATO"
log "========================================="

exit 0
AUTOCHECK_EOF

    chmod +x "$autocheck_script"
    log "Script autocheck creato: $autocheck_script"
    
    # Configura rc.local per esecuzione all'avvio
    if [ ! -f "$rc_local" ]; then
        log "Creo $rc_local"
        cat > "$rc_local" <<'RCLOCAL'
#!/bin/sh
# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.

exit 0
RCLOCAL
        chmod +x "$rc_local"
    fi
    
    # Aggiungi autocheck a rc.local se non presente
    if ! grep -q 'rocksolid-startup-check.sh' "$rc_local"; then
        log "Aggiungo autocheck a rc.local"
        # Rimuovi exit 0 temporaneamente
        sed -i '/^exit 0/d' "$rc_local"
        # Aggiungi script e exit 0
        echo "$autocheck_script &" >> "$rc_local"
        echo "exit 0" >> "$rc_local"
        log "Autocheck configurato per esecuzione all'avvio"
    else
        log "Autocheck già presente in rc.local"
    fi
    
    # Proteggi file autocheck in sysupgrade.conf
    add_to_sysupgrade "$autocheck_script" "ROCKSOLID Startup Autocheck Script"
    add_to_sysupgrade "$rc_local" "Boot Script (rc.local)"
    add_to_sysupgrade "$autocheck_log" "ROCKSOLID Autocheck Log"
    
    log "Autocheck installato e protetto"
    
    # Test immediato
    log "Test esecuzione autocheck..."
    if "$autocheck_script"; then
        log "Test autocheck completato - verifica log in $autocheck_log"
    else
        warn "Test autocheck fallito"
    fi
}

uninstall_all() {
    log "Disinstallazione Checkmk Agent + FRP client"

    if [ -x "$FRPC_INIT" ]; then
        /etc/init.d/frpc stop >/dev/null 2>&1 || true
        /etc/init.d/frpc disable >/dev/null 2>&1 || true
    fi

    if [ -x /etc/init.d/check_mk_agent ]; then
        /etc/init.d/check_mk_agent stop >/dev/null 2>&1 || true
        /etc/init.d/check_mk_agent disable >/dev/null 2>&1 || true
        rm -f /etc/init.d/check_mk_agent
    fi

    killall frpc socat >/dev/null 2>&1 || true

    rm -rf /etc/frp >/dev/null 2>&1 || true
    rm -f "$FRPC_BIN" "$FRPC_INIT" "$FRPC_LOG" >/dev/null 2>&1 || true

    rm -f /usr/bin/check_mk_agent >/dev/null 2>&1 || true
    rm -rf /etc/check_mk /etc/xinetd.d/check_mk >/dev/null 2>&1 || true
    
    # Rimuovi anche script post-upgrade
    rm -f /etc/checkmk-post-upgrade.sh >/dev/null 2>&1 || true

    log "Disinstallazione completata"
    warn "NOTA: le entry in $SYSUPGRADE_CONF non sono state rimosse"
    warn "Per rimuoverle manualmente, modifica $SYSUPGRADE_CONF"
}

install_prereqs() {
    need_cmd opkg

    log "Configuro repository (customfeeds)"
    mkdir -p "$(dirname "$CUSTOMFEEDS")" 2>/dev/null || true
    [ -f "$CUSTOMFEEDS" ] || : >"$CUSTOMFEEDS"

    add_repo "openwrt_base" "$REPO_BASE"
    add_repo "openwrt_packages" "$REPO_PACKAGES"

    log "opkg update"
    opkg update
    
    # Verifica e ripara repository corrotti (post-upgrade)
    if opkg list 2>&1 | grep -q "parse_from_stream_nomalloc"; then
        warn "Repository corrotti rilevati - riparo"
        rm -rf /var/opkg-lists/*.sig 2>/dev/null || true
        opkg update || warn "Alcuni repository hanno fallito (normale post-upgrade)"
    fi

    log "Installo tool necessari (binutils/tar/gzip/wget/socat/ca-certificates)"
    # ar e' in binutils - ignora errori se già installati
    opkg install binutils tar gzip wget socat ca-certificates 2>/dev/null || \
        log "Alcuni pacchetti già installati o non disponibili (continuo comunque)"

    need_cmd ar
    need_cmd tar
    need_cmd wget
    need_cmd socat
}

install_agent() {
    log "Installazione Checkmk agent"

    rm -rf "$TMPDIR" >/dev/null 2>&1 || true
    mkdir -p "$TMPDIR/data"
    cd "$TMPDIR" || die "cd fallito: $TMPDIR"

    log "Download .deb agente"
    wget -O check-mk-agent.deb "$DEB_URL" || die "download fallito: $DEB_URL"

    log "Estrazione .deb (ar + tar)"
    ar x check-mk-agent.deb || die "ar x fallito"

    # Debian packages: data.tar.gz or data.tar.xz
    if [ -f data.tar.gz ]; then
        tar -xzf data.tar.gz -C data || die "tar -xzf fallito"
    elif [ -f data.tar.xz ]; then
        tar -xJf data.tar.xz -C data || die "tar -xJf fallito"
    else
        die "data.tar.* non trovato nel .deb"
    fi

    if [ ! -f data/usr/bin/check_mk_agent ]; then
        die "file mancante dopo estrazione: data/usr/bin/check_mk_agent"
    fi

    log "Copia binario agente"
    mkdir -p /usr/bin
    cp -f data/usr/bin/check_mk_agent /usr/bin/check_mk_agent
    chmod +x /usr/bin/check_mk_agent

    log "Copia configurazione (best effort)"
    mkdir -p /etc/check_mk
    if [ -d data/etc/check_mk ]; then
        cp -rf data/etc/check_mk/* /etc/check_mk/ 2>/dev/null || true
    fi

    cd / || true
    rm -rf "$TMPDIR" >/dev/null 2>&1 || true

    log "Agente installato: /usr/bin/check_mk_agent"
}

install_agent_service() {
    log "Creo servizio procd (socat listener su 6556)"

    cat >/etc/init.d/check_mk_agent <<'EOF'
#!/bin/sh /etc/rc.common
START=98
STOP=10
USE_PROCD=1

PROG=/usr/bin/check_mk_agent

start_service() {
    procd_open_instance
    procd_set_param respawn
    procd_set_param command socat TCP-LISTEN:6556,reuseaddr,fork,keepalive EXEC:$PROG
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    killall socat >/dev/null 2>&1 || true
}
EOF

    chmod +x /etc/init.d/check_mk_agent
    /etc/init.d/check_mk_agent enable >/dev/null 2>&1 || true
    /etc/init.d/check_mk_agent restart >/dev/null 2>&1 || /etc/init.d/check_mk_agent start >/dev/null 2>&1 || true

    # Best effort check
    if pgrep -f "socat TCP-LISTEN:6556" >/dev/null 2>&1; then
        log "Checkmk agent in ascolto su TCP 6556 (socat)"
    else
        warn "socat non risulta in esecuzione: verificare /etc/init.d/check_mk_agent e log di sistema"
    fi
}

install_frp() {
    echo ""
    echo "Installazione FRP client (opzionale)"
    echo "Server remoto: monitor.nethlab.it:7000"
    echo ""
    
    # Controlla se esiste già una configurazione FRP
    EXISTING_CONFIG=""
    if [ -f "$FRPC_CONF" ]; then
        log "Configurazione FRP esistente trovata: $FRPC_CONF"
        
        # Estrai parametri dalla configurazione esistente
        SERVER_ADDR=$(grep '^serverAddr' "$FRPC_CONF" | sed 's/.*= *"\([^"]*\)".*/\1/' | grep -v '^$')
        SERVER_PORT=$(grep '^serverPort' "$FRPC_CONF" | sed 's/.*= *\([0-9][0-9]*\).*/\1/')
        FRP_TOKEN=$(grep '^auth.token' "$FRPC_CONF" | sed 's/.*= *"\([^"]*\)".*/\1/' | grep -v '^$')
        PROXY_NAME=$(grep '^\[\[proxies\]\]' -A 10 "$FRPC_CONF" | grep '^name' | sed 's/.*= *"\([^"]*\)".*/\1/' | grep -v '^$' | head -1)
        REMOTE_PORT=$(grep '^\[\[proxies\]\]' -A 10 "$FRPC_CONF" | grep '^remotePort' | sed 's/.*= *\([0-9][0-9]*\).*/\1/' | head -1)
        
        # Valida configurazione estratta - tutti i valori devono essere non-vuoti
        if [ -n "$SERVER_ADDR" ] && [ -n "$SERVER_PORT" ] && [ -n "$FRP_TOKEN" ] && [ -n "$PROXY_NAME" ] && [ -n "$REMOTE_PORT" ]; then
            EXISTING_CONFIG="yes"
            log "Configurazione recuperata:"
            log "  Server: $SERVER_ADDR:$SERVER_PORT"
            log "  Proxy: $PROXY_NAME (porta remota: $REMOTE_PORT)"
            echo ""
        else
            warn "Configurazione FRP esistente incompleta o invalida"
            warn "  serverAddr: ${SERVER_ADDR:-VUOTO}"
            warn "  serverPort: ${SERVER_PORT:-VUOTO}"
            warn "  token: ${FRP_TOKEN:+PRESENTE}${FRP_TOKEN:-VUOTO}"
            warn "  proxy name: ${PROXY_NAME:-VUOTO}"
            warn "  remotePort: ${REMOTE_PORT:-VUOTO}"
            warn "Richiesta nuova configurazione"
            echo ""
        fi
        
        # Se non-interattivo (boot/auto), mantieni sempre config esistente
        if ! is_interactive; then
            log "Modalita non-interattiva: mantengo configurazione esistente"
        else
            printf "Vuoi mantenere questa configurazione? [Y/n]: "
            read ans || ans=""
            ans_lc=$(printf "%s" "$ans" | tr '[:upper:]' '[:lower:]')
            case "$ans_lc" in
                n|no) EXISTING_CONFIG="" ;;
                *) ;;
            esac
        fi
    fi
    
    # Se non c'è configurazione esistente o l'utente vuole cambiarla
    if [ -z "$EXISTING_CONFIG" ]; then
        # Se non-interattivo senza config esistente, salta FRP
        if ! is_interactive; then
            log "Modalita non-interattiva: nessuna config FRP esistente, salto installazione"
            return 0
        fi
        
        printf "Vuoi installare e configurare il client FRP? [y/N]: "
        read ans || ans=""
        ans_lc=$(printf "%s" "$ans" | tr '[:upper:]' '[:lower:]')
        case "$ans_lc" in
            y|yes|s|si) ;;
            *) return 0 ;;
        esac

        SERVER_ADDR="monitor.nethlab.it"
        SERVER_PORT="7000"

        while :; do
            printf "Inserisci la remote_port da assegnare (es. 6020): "
            read REMOTE_PORT || REMOTE_PORT=""
            echo "$REMOTE_PORT" | grep -Eq '^[0-9]+$' && break
            echo "Valore non valido"
        done

        printf "Inserisci la chiave/token FRP: "
        read FRP_TOKEN || FRP_TOKEN=""
        [ -n "$FRP_TOKEN" ] || die "token FRP vuoto"

        DEFAULT_NAME="$(hostname 2>/dev/null || echo openwrt-host)"
        printf "Nome proxy FRP (default: %s): " "$DEFAULT_NAME"
        read PROXY_NAME || PROXY_NAME=""
        [ -n "$PROXY_NAME" ] || PROXY_NAME="$DEFAULT_NAME"
    fi

    cd /tmp || die "cd /tmp fallito"
    FRP_TGZ="frp_${FRP_VER}_linux_amd64.tar.gz"
    FRP_DL="https://github.com/fatedier/frp/releases/download/v${FRP_VER}/${FRP_TGZ}"

    log "Download FRP v$FRP_VER"
    wget -O "$FRP_TGZ" "$FRP_DL" || die "download FRP fallito"

    log "Estrazione FRP"
    tar -xzf "$FRP_TGZ" || die "tar frp fallito"
    FRP_DIR="$(tar -tzf "$FRP_TGZ" | head -n1 | cut -d/ -f1)"

    [ -n "$FRP_DIR" ] || die "impossibile determinare directory estratta"
    [ -f "$FRP_DIR/frpc" ] || die "frpc non trovato nel tarball"

    mkdir -p "$(dirname "$FRPC_BIN")" /etc/frp /var/log
    cp -f "$FRP_DIR/frpc" "$FRPC_BIN"
    chmod +x "$FRPC_BIN"

    rm -f "$FRP_TGZ"
    rm -rf "$FRP_DIR"

    log "Scrivo configurazione TOML: $FRPC_CONF"
    cat >"$FRPC_CONF" <<EOF
serverAddr = "$SERVER_ADDR"
serverPort = $SERVER_PORT

auth.method = "token"
auth.token = "$FRP_TOKEN"

transport.tls.enable = true

log.to = "$FRPC_LOG"
log.level = "info"

[[proxies]]
name = "$PROXY_NAME"
type = "tcp"
localIP = "127.0.0.1"
localPort = 6556
remotePort = $REMOTE_PORT
EOF

    log "Creo servizio procd FRP: $FRPC_INIT"
    cat >"$FRPC_INIT" <<'EOF'
#!/bin/sh /etc/rc.common
START=99
STOP=10
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param respawn
    procd_set_param command /usr/local/bin/frpc -c /etc/frp/frpc.toml
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    killall frpc >/dev/null 2>&1 || true
}
EOF

    chmod +x "$FRPC_INIT"
    /etc/init.d/frpc enable >/dev/null 2>&1 || true
    /etc/init.d/frpc restart >/dev/null 2>&1 || /etc/init.d/frpc start >/dev/null 2>&1 || true

    if pgrep -f frpc >/dev/null 2>&1; then
        log "FRP attivo: proxy=$PROXY_NAME remote_port=$REMOTE_PORT"
    else
        warn "FRP non risulta in esecuzione: controllare log $FRPC_LOG"
    fi
    
    # ROCKSOLID: Proteggi installazione FRP
    protect_frp_installation
}

main() {
    if [ "${1:-}" = "--uninstall" ]; then
        is_root || die "eseguire come root"
        uninstall_all
        exit 0
    fi

    is_root || die "eseguire come root"

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  CheckMK Agent Installer - ROCKSOLID Edition                  ║"
    echo "║  Versione resistente ai major upgrade NethSecurity/OpenWrt    ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    log "Configurazione:"
    log "  CheckMK Server: $CMK_SERVER"
    log "  Site: $CMK_SITE"
    log "  Protocol: $CMK_PROTOCOL"
    echo ""

    install_prereqs
    detect_checkmk_agent_url
    install_agent
    install_agent_service
    
    # ROCKSOLID: Proteggi installazione
    protect_checkmk_installation
    backup_critical_binaries
    create_post_upgrade_script
    
    install_frp
    
    # ROCKSOLID: Installa autocheck all'avvio
    install_autocheck

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  INSTALLAZIONE COMPLETATA - ROCKSOLID MODE ATTIVO             ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Protezioni attivate:"
    echo "  ✓ File critici aggiunti a $SYSUPGRADE_CONF"
    echo "  ✓ Binari critici backuppati (tar/ar/gzip protetti da corruzione)"
    echo "  ✓ Script post-upgrade: /etc/checkmk-post-upgrade.sh"
    echo "  ✓ Script autocheck avvio: /usr/local/bin/rocksolid-startup-check.sh"
    echo "  ✓ Installazione resistente ai major upgrade"
    echo ""
    echo "Autocheck all'avvio:"
    echo "  ✓ Verifica e riavvia CheckMK Agent automaticamente"
    echo "  ✓ Verifica e riavvia FRP Client automaticamente"
    echo "  ✓ Log: /var/log/rocksolid-startup.log"
    echo ""
    echo "Test agent locale: nc 127.0.0.1 6556 | head"
    echo "Config FRP: $FRPC_CONF"
    echo "Disinstallazione: sh $0 --uninstall"
    echo ""
    echo "IMPORTANTE: Dopo un major upgrade, esegui /etc/checkmk-post-upgrade.sh"
    echo "            per verificare e ripristinare i servizi"
}

main "$@"

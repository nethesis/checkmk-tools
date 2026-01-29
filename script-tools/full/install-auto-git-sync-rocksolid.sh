#!/bin/bash
# ==========================================================
#  Installazione Auto Git Sync Service - ROCKSOLID Edition
#  ROCKSOLID: Resiste ai major upgrade di NethSecurity/OpenWrt
#  Installa e configura il servizio di sync automatico
#  Autore: ChatGPT per Marzio Bordin
# ==========================================================

set -e

# Avoid getcwd/job-working-directory warnings if the current directory is removed
# (e.g., repo being recloned while this installer runs).
cd / 2>/dev/null || true

SYSUPGRADE_CONF="${SYSUPGRADE_CONF:-/etc/sysupgrade.conf}"

# ============================================================================
# ROCKSOLID: Funzione per aggiungere file a sysupgrade.conf
# ============================================================================
add_to_sysupgrade() {
    local file_path="$1"
    local comment="${2:-}"
    
    # Crea il file se non esiste
    if [ ! -f "$SYSUPGRADE_CONF" ]; then
        echo "i  Creo $SYSUPGRADE_CONF"
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
    echo "OK Protetto: $file_path"
}

# ============================================================================
# ROCKSOLID: Proteggi installazione Git Sync Service
# ============================================================================
protect_git_sync_installation() {
    echo ""
    echo "========================================="
    echo "  ROCKSOLID: Protezione Installazione"
    echo "========================================="
    echo ""
    
    # Service file systemd
    add_to_sysupgrade "/etc/systemd/system/auto-git-sync.service" "Auto Git Sync - Service File"
    
    # Log file
    add_to_sysupgrade "/var/log/auto-git-sync.log" "Auto Git Sync - Log File"
    
    # Repository directory (se in /opt)
    if [[ -d "/opt/checkmk-tools/.git" ]]; then
        add_to_sysupgrade "/opt/checkmk-tools/" "CheckMK Tools Repository"
    fi
    
    echo "OK Installazione Git Sync protetta contro major upgrade"
}

# ============================================================================
# ROCKSOLID: Crea script di ripristino post-upgrade
# ============================================================================
create_post_upgrade_script() {
    local script_path="/etc/git-sync-post-upgrade.sh"
    
    echo "i  Creo script di ripristino post-upgrade: $script_path"
    
    cat > "$script_path" <<'POSTSCRIPT'
#!/bin/bash
# Script eseguito automaticamente dopo major upgrade
# Verifica e ripristina servizio Git Sync se necessario

log() { logger -t git-sync-post-upgrade "$*"; echo "[POST-UPGRADE] $*"; }

log "Verifica installazione Git Sync post-upgrade"

# Verifica service file
if [ ! -f /etc/systemd/system/auto-git-sync.service ]; then
    log "ERRORE: /etc/systemd/system/auto-git-sync.service mancante dopo upgrade!"
    log "Reinstalla il servizio con install-auto-git-sync-rocksolid.sh"
    exit 1
fi

# Verifica repository
if [ ! -d /opt/checkmk-tools/.git ]; then
    log "WARN: Repository /opt/checkmk-tools non trovato"
    log "Il servizio potrebbe non funzionare correttamente"
fi

# Ricarica systemd
log "Ricarico systemd daemon"
systemctl daemon-reload 2>/dev/null || true

# Riattiva servizio
log "Riattivo servizio auto-git-sync"
systemctl enable auto-git-sync.service 2>/dev/null || true
systemctl restart auto-git-sync.service 2>/dev/null || true

# Verifica stato
sleep 2
if systemctl is-active --quiet auto-git-sync.service; then
    log "Servizio auto-git-sync attivo e funzionante"
else
    log "WARN: Servizio auto-git-sync non attivo, verifica configurazione"
    systemctl status auto-git-sync.service --no-pager || true
fi

log "Verifica completata"
POSTSCRIPT

    chmod +x "$script_path"
    
    # Proteggi anche lo script stesso
    add_to_sysupgrade "$script_path" "Post-upgrade verification script for Git Sync"
    
    echo "OK Script post-upgrade creato e protetto"
}

detect_os() {
    OS_ID="unknown"
    OS_LIKE=""
    OS_VERSION_ID=""
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_LIKE="${ID_LIKE:-}"
        OS_VERSION_ID="${VERSION_ID:-}"
    fi
    export OS_ID OS_LIKE OS_VERSION_ID
}

pick_pkg_manager() {
    PKG_MGR=""
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MGR="yum"
    fi
    export PKG_MGR
}

pkg_update() {
    case "${PKG_MGR:-}" in
        apt) timeout 300 apt-get update -qq || true ;;
        yum) timeout 300 yum -y makecache fast || timeout 300 yum -y makecache || true ;;
        dnf) timeout 300 dnf -y makecache || true ;;
        *) return 1 ;;
    esac
}

pkg_install_git() {
    case "${PKG_MGR:-}" in
        apt)
            pkg_update
            timeout 300 apt-get install -y git
            ;;
        yum)
            pkg_update
            timeout 300 yum install -y git
            ;;
        dnf)
            pkg_update
            timeout 300 dnf install -y git
            ;;
        *)
            echo " Package manager non supportato. Installa git manualmente."
            return 1
            ;;
    esac
}

pkg_upgrade_git() {
    case "${PKG_MGR:-}" in
        apt)
            pkg_update
            timeout 300 apt-get install -y git || true
            ;;
        yum)
            pkg_update
            # On CentOS/RHEL 7 this may still keep git 1.8.x unless extra repos are enabled.
            timeout 300 yum -y update git || timeout 300 yum -y install git || true
            ;;
        dnf)
            pkg_update
            timeout 300 dnf -y upgrade git || timeout 300 dnf -y install git || true
            ;;
        *)
            echo "WARN  Package manager non supportato per upgrade automatico."
            ;;
    esac
}

detect_os
pick_pkg_manager

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Auto Git Sync Installer - ROCKSOLID Edition                  ║"
echo "║  Versione resistente ai major upgrade NethSecurity/OpenWrt    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "i  OS rilevato: ${OS_ID}${OS_VERSION_ID:+ $OS_VERSION_ID}${OS_LIKE:+ (like: $OS_LIKE)}"
if [[ -n "${PKG_MGR:-}" ]]; then
    echo "i  Package manager: ${PKG_MGR}"
fi

# Funzione per installare git
install_git() {
    echo "i  Git non trovato, installazione in corso..."
    if ! pkg_install_git; then
        echo " Errore durante installazione git"
        exit 1
    fi
    echo "OK Git installato"
}

# Verifica se git e installato
if ! command -v git &> /dev/null; then
    install_git
fi

get_git_version() {
    # Example: "git version 1.8.3.1" -> "1.8.3.1"
    git --version 2>/dev/null | awk '{print $3}'
}

maybe_upgrade_git() {
    local ver major minor
    ver="$(get_git_version)"
    if [[ -z "${ver:-}" ]]; then
        return 0
    fi
    major="${ver%%.*}"
    local rest
    rest="${ver#*.}"
    minor="${rest%%.*}"
    major="${major:-0}"
    minor="${minor:-0}"

    # Git < 2.x is very old; offer an upgrade (best-effort).
    if [[ "$major" =~ ^[0-9]+$ ]] && [[ "$major" -lt 2 ]]; then
        echo "WARN  Git rilevato: $ver (molto vecchio)"
        echo "   Posso provare ad aggiornarlo (best-effort) tramite il package manager."
        read -r -p "Vuoi provare ad aggiornare Git ora? [s/N]: " upgrade_choice
        upgrade_choice="${upgrade_choice//$'\r'/}"
        if [[ "$upgrade_choice" =~ ^[SsYy]$ ]]; then
            echo "i  Tentativo aggiornamento Git..."
			pkg_upgrade_git

            local new_ver
            new_ver="$(get_git_version)"
            if [[ -n "${new_ver:-}" ]]; then
                echo "i  Git versione attuale: $new_ver"
            fi
        else
            echo "i  Upgrade Git saltato."
        fi
    fi
}

maybe_upgrade_git

# Cerca il repository checkmk-tools
# Priorita: /opt, poi /root, poi $HOME
if [[ -d "/opt/checkmk-tools/.git" ]]; then
    REPO_DIR="/opt/checkmk-tools"
elif [[ -d "/root/checkmk-tools/.git" ]]; then
    REPO_DIR="/root/checkmk-tools"
elif [[ -d "$HOME/checkmk-tools/.git" ]]; then
    REPO_DIR="$HOME/checkmk-tools"
else
    echo " Repository checkmk-tools non trovato"
    echo "   Posizioni cercate:"
    echo "   - /opt/checkmk-tools (consigliato)"
    echo "   - /root/checkmk-tools"
    echo "   - $HOME/checkmk-tools"
    echo ""
    echo "i  Se vuoi clonare il repository in /opt/checkmk-tools:"
    echo "   cd /opt && git clone https://github.com/Coverup20/checkmk-tools.git"
    echo ""
    read -r -p "Inserisci il path del repository [/opt/checkmk-tools]: " REPO_DIR
    REPO_DIR="${REPO_DIR:-/opt/checkmk-tools}"
    
    # Se non esiste, offre di clonarlo
    if [[ ! -d "$REPO_DIR/.git" ]]; then
        read -r -p "Repository non trovato. Vuoi clonarlo in $REPO_DIR? [S/n]: " clone_choice
        if [[ "$clone_choice" =~ ^[Nn] ]]; then
            echo " Installazione annullata"
            exit 1
        fi
        
        # Crea directory parent se non esiste
        PARENT_DIR=$(dirname "$REPO_DIR")
        mkdir -p "$PARENT_DIR"
        
        echo " Clonazione repository in $REPO_DIR..."
        if ! timeout 120 git clone https://github.com/Coverup20/checkmk-tools.git "$REPO_DIR" 2>&1; then
            echo " Errore durante la clonazione (timeout o errore rete)"
            exit 1
        fi
        
        # Verifica che il clone sia riuscito
        if [[ ! -d "$REPO_DIR/.git" ]]; then
            echo " Repository clonato ma .git non trovato"
            exit 1
        fi
        echo "OK Repository clonato con successo"
    fi
fi

echo "========================================="
echo "  Installazione Auto Git Sync Service"
echo "========================================="
echo ""

# Verifica esecuzione come root
if [[ $EUID -ne 0 ]]; then
    echo " Questo script deve essere eseguito come root"
    echo "   Usa: sudo bash install-auto-git-sync-rocksolid.sh"
    exit 1
fi
echo "OK Esecuzione come root"

# Chiedi intervallo di sync
echo ""
echo "  Configurazione intervallo di sync"
echo ""
echo "Scegli ogni quanto eseguire il git pull:"
echo "  1) Ogni 30 secondi"
echo "  2) Ogni 1 minuto (consigliato)"
echo "  3) Ogni 5 minuti"
echo "  4) Ogni 10 minuti"
echo "  5) Ogni 30 minuti"
echo "  6) Personalizzato"
echo ""
read -r -p "Scelta [2]: " interval_choice

# Normalize common terminal artifacts (spaces, tabs, CRLF).
interval_choice="${interval_choice//$'\r'/}"
interval_choice="${interval_choice//$'\n'/}"
interval_choice="${interval_choice//$'\t'/}"
interval_choice="${interval_choice// /}"

case "$interval_choice" in
    1) SYNC_INTERVAL=30 ;;
    2|"") SYNC_INTERVAL=60 ;;
    3) SYNC_INTERVAL=300 ;;
    4) SYNC_INTERVAL=600 ;;
    5) SYNC_INTERVAL=1800 ;;
    6)
        read -r -p "Inserisci intervallo in secondi (10-3600): " SYNC_INTERVAL
        if ! [[ "$SYNC_INTERVAL" =~ ^[0-9]+$ ]] || [ "$SYNC_INTERVAL" -lt 10 ] || [ "$SYNC_INTERVAL" -gt 3600 ]; then
            echo " Valore non valido (deve essere tra 10 e 3600), uso default 60 secondi"
            SYNC_INTERVAL=60
        fi
        ;;
    *)
        echo " Scelta non valida, uso default 60 secondi"
        SYNC_INTERVAL=60
        ;;
esac

echo "OK Intervallo impostato: $SYNC_INTERVAL secondi"
echo ""

# Rileva l'utente proprietario del repository
REPO_OWNER=$(stat -c '%U' "$REPO_DIR" 2>/dev/null || echo "root")
REPO_OWNER_HOME=$(eval echo "~$REPO_OWNER" 2>/dev/null || echo "/root")

echo "i  Repository owner: $REPO_OWNER"
echo "i  Repository path: $REPO_DIR"
echo "i  Home directory: $REPO_OWNER_HOME"
echo ""

# Il servizio esegue direttamente da GitHub, non serve controllare il file locale
echo "i  Il servizio eseguira lo script direttamente da GitHub"

# Crea directory log se non esiste
if ! mkdir -p /var/log 2>/dev/null; then
    echo "WARN  Impossibile creare directory /var/log (gia esistente)"
fi

if touch /var/log/auto-git-sync.log 2>/dev/null; then
    chown "$REPO_OWNER:$REPO_OWNER" /var/log/auto-git-sync.log 2>/dev/null || echo "WARN  Impossibile cambiare owner del log file"
    echo "OK Log file preparato"
else
    echo "WARN  Impossibile creare log file, verra usato journalctl"
fi

# Crea service file personalizzato che esegue direttamente da GitHub
echo "i  Creazione service file personalizzato..."
cat > /etc/systemd/system/auto-git-sync.service << 'EOF'
[Unit]
Description=Auto Git Sync Service (ROCKSOLID)
Documentation=https://github.com/Coverup20/checkmk-tools
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=PLACEHOLDER_USER
Group=PLACEHOLDER_GROUP
WorkingDirectory=PLACEHOLDER_HOME
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="HOME=PLACEHOLDER_HOME"
ExecStart=/bin/bash -c 'set -euo pipefail; TEMP_SCRIPT=$(mktemp); cleanup(){ rm -f "$TEMP_SCRIPT" "$TEMP_SCRIPT.lf" 2>/dev/null || true; }; trap cleanup EXIT; curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/auto-git-sync.sh -o "$TEMP_SCRIPT"; if [[ ! -s "$TEMP_SCRIPT" ]]; then echo "auto-git-sync: download produced empty file" >&2; exit 1; fi; lf_count=$(LC_ALL=C tr -cd "\n" <"$TEMP_SCRIPT" | wc -c | tr -d " "); if [[ "${lf_count:-0}" == "0" ]]; then LC_ALL=C tr "\r" "\n" <"$TEMP_SCRIPT" >"$TEMP_SCRIPT.lf"; mv -f "$TEMP_SCRIPT.lf" "$TEMP_SCRIPT"; fi; sed -i "s/\r$//" "$TEMP_SCRIPT" 2>/dev/null || true; if ! bash -n "$TEMP_SCRIPT"; then echo "auto-git-sync: downloaded script is not valid bash" >&2; head -n 80 "$TEMP_SCRIPT" >&2 || true; exit 1; fi; bash "$TEMP_SCRIPT" PLACEHOLDER_INTERVAL'
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=auto-git-sync

# Security hardening - permetti scrittura in repo (include .git)
PrivateTmp=yes
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
EOF

# Sostituisci placeholder con valori reali
sed -i "s|PLACEHOLDER_USER|$REPO_OWNER|g" /etc/systemd/system/auto-git-sync.service
sed -i "s|PLACEHOLDER_GROUP|$REPO_OWNER|g" /etc/systemd/system/auto-git-sync.service
sed -i "s|PLACEHOLDER_HOME|$REPO_OWNER_HOME|g" /etc/systemd/system/auto-git-sync.service
sed -i "s|PLACEHOLDER_REPO|$REPO_DIR|g" /etc/systemd/system/auto-git-sync.service
sed -i "s|PLACEHOLDER_INTERVAL|$SYNC_INTERVAL|g" /etc/systemd/system/auto-git-sync.service

echo "OK Service file creato e installato"

# Verifica che systemd sia disponibile
if ! command -v systemctl &> /dev/null; then
    echo " systemd non disponibile su questo sistema"
    echo "   Il servizio non puo essere installato"
    exit 1
fi

# Ricarica systemd
if ! systemctl daemon-reload 2>&1; then
    echo " Errore durante reload di systemd"
    exit 1
fi
echo "OK Systemd ricaricato"

# Abilita il servizio all'avvio
if ! systemctl enable auto-git-sync.service 2>&1; then
    echo " Errore durante abilitazione servizio"
    exit 1
fi
echo "OK Servizio abilitato all'avvio"

# ROCKSOLID: Proteggi installazione
protect_git_sync_installation
create_post_upgrade_script

# Riavvia il servizio se gia attivo
if systemctl is-active --quiet auto-git-sync.service; then
    echo "i  Servizio gia attivo, riavvio in corso..."
    systemctl restart auto-git-sync.service
    echo "OK Servizio riavviato con nuova configurazione"
fi

# Mostra menu opzioni
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  INSTALLAZIONE COMPLETATA - ROCKSOLID MODE ATTIVO             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo " Configurazione:"
echo "   - Utente: $REPO_OWNER"
echo "   - Repository: $REPO_DIR"
echo "   - Intervallo sync: $SYNC_INTERVAL secondi"
echo ""
echo "Protezioni attivate:"
echo "  ✓ Service file protetto in $SYSUPGRADE_CONF"
echo "  ✓ Script post-upgrade creato: /etc/git-sync-post-upgrade.sh"
echo "  ✓ Installazione resistente ai major upgrade"
echo ""
echo "Comandi disponibili:"
echo ""
echo "  - Avvia servizio:"
echo "    systemctl start auto-git-sync"
echo ""
echo "  - Ferma servizio:"
echo "    systemctl stop auto-git-sync"
echo ""
echo "  - Riavvia servizio:"
echo "    systemctl restart auto-git-sync"
echo ""
echo "  - Stato servizio:"
echo "    systemctl status auto-git-sync"
echo ""
echo "  - Log in tempo reale:"
echo "    journalctl -u auto-git-sync -f"
echo ""
echo "  - Log completo:"
echo "    tail -f /var/log/auto-git-sync.log"
echo ""
echo "  - Disabilita servizio:"
echo "    systemctl disable auto-git-sync"
echo ""
echo "IMPORTANTE: Dopo un major upgrade, esegui /etc/git-sync-post-upgrade.sh"
echo "            per verificare e ripristinare il servizio"
echo ""

read -r -p "Vuoi avviare il servizio ora? (s/N): " start_now
if [[ "$start_now" =~ ^[sS]$ ]]; then
    systemctl start auto-git-sync
    echo ""
    echo "OK Servizio avviato!"
    echo ""
    sleep 2
    systemctl status auto-git-sync --no-pager
else
    echo ""
    echo "i  Servizio non avviato. Usa 'systemctl start auto-git-sync' per avviarlo."
fi
echo ""
echo "========================================="

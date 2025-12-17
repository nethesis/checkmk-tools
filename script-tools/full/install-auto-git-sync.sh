#!/bin/bash
# ==========================================================
#  Installazione Auto Git Sync Service
#  Installa e configura il servizio di sync automatico
#  Autore: ChatGPT per Marzio Bordin
# ==========================================================

set -e

# Funzione per installare git
install_git() {
    echo "ℹ️  Git non trovato, installazione in corso..."
    if command -v apt-get &> /dev/null; then
        timeout 300 apt-get update -qq && timeout 300 apt-get install -y git || {
            echo "❌ Timeout durante installazione git"
            exit 1
        }
    el
if command -v yum &> /dev/null; then
        timeout 300 yum install -y git || {
            echo "❌ Timeout durante installazione git"
            exit 1
        }
    el
if command -v dnf &> /dev/null; then
        timeout 300 dnf install -y git || {
            echo "❌ Timeout durante installazione git"
            exit 1
        }
    else
        echo "❌ Package manager non supportato. Installa git manualmente:"
        echo "   - Debian/Ubuntu: apt-get install git"
        echo "   - CentOS/RHEL: yum install git"
        exit 1
    fi
    echo "✅ Git installato"
}

# Verifica se git è installato
if ! command -v git &> /dev/null; then
    install_git
fi

# Cerca il repository checkmk-tools
# Priorità: /opt, poi /root, poi $HOME
if [[ -d "/opt/checkmk-tools/.git" ]]; then
    REPO_DIR="/opt/checkmk-tools"
el
if [[ -d "/root/checkmk-tools/.git" ]]; then
    REPO_DIR="/root/checkmk-tools"
el
if [[ -d "$HOME/checkmk-tools/.git" ]]; then
    REPO_DIR="$HOME/checkmk-tools"
else
    echo "❌ Repository checkmk-tools non trovato"
    echo "   Posizioni cercate:"
    echo "   - /opt/checkmk-tools (consigliato)"
    echo "   - /root/checkmk-tools"
    echo "   - $HOME/checkmk-tools"
    echo ""
    echo "ℹ️  Se vuoi clonare il repository in /opt/checkmk-tools:"
    echo "   cd /opt && git clone https://github.com/Coverup20/checkmk-tools.git"
    echo ""
    read -r -p "Inserisci il path del repository [/opt/checkmk-tools]: " REPO_DIR
    REPO_DIR="${REPO_DIR:-/opt/checkmk-tools}"
    
    # Se non esiste, offre di clonarlo
    if [[ ! -d "$REPO_DIR/.git" ]]; then
        read -r -p "Repository non trovato. Vuoi clonarlo in $REPO_DIR? [S/n]: " clone_choice
        if [[ "$clone_choice" =~ ^[Nn] ]]; then
            echo "❌ Installazione annullata"
            exit 1
        fi
        
        # Crea directory parent se non esiste
        PARENT_DIR=$(dirname "$REPO_DIR")
        mkdir -p "$PARENT_DIR"
        
        echo "📥 Clonazione repository in $REPO_DIR..."
        if ! timeout 120 git clone https://github.com/Coverup20/checkmk-tools.git "$REPO_DIR" 2>&1; then
            echo "❌ Errore durante la clonazione (timeout o errore rete)"
            exit 1
        fi
        
        # Verifica che il clone sia riuscito
        if [[ ! -d "$REPO_DIR/.git" ]]; then
            echo "❌ Repository clonato ma .git non trovato"
            exit 1
        fi
        
        echo "✅ Repository clonato con successo"
    fi
fi

echo "========================================="
echo "  Installazione Auto Git Sync Service"
echo "========================================="
echo ""

# Verifica esecuzione come root
if [[ $EUID -ne 0 ]]; then
    echo "❌ Questo script deve essere eseguito come root"
    echo "   Usa: su
do bash install-auto-git-sync.sh"
    exit 1
fi
echo "✅ Esecuzione come root"

# Chiedi intervallo di sync
echo ""
echo "⏱️  Configurazione intervallo di sync"
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

case "$interval_choice" in
    1) SYNC_INTERVAL=30 ;;
    2|"") SYNC_INTERVAL=60 ;;
    3) SYNC_INTERVAL=300 ;;
    4) SYNC_INTERVAL=600 ;;
    5) SYNC_INTERVAL=1800 ;;
    6)
        read -r -p "Inserisci intervallo in secondi (10-3600): " SYNC_INTERVAL
        if ! [[ "$SYNC_INTERVAL" =~ ^[0-9]+$ ]] || [ "$SYNC_INTERVAL" -lt 10 ] || [ "$SYNC_INTERVAL" -gt 3600 ]; then
            echo "❌ Valore non vali
do (deve essere tra 10 e 3600), uso default 60 secondi"
            SYNC_INTERVAL=60
        fi
        ;;
    *)
        echo "❌ Scelta non valida, uso default 60 secondi"
        SYNC_INTERVAL=60
        ;;
esac

echo "✅ Intervallo impostato: $SYNC_INTERVAL secondi"
echo ""

# Rileva l'utente proprietario del repository
REPO_OWNER=$(stat -c '%U' "$REPO_DIR" 2>/dev/null || echo "root")
REPO_OWNER_HOME=$(eval echo "~$REPO_OWNER" 2>/dev/null || echo "/root")

echo "ℹ️  Repository owner: $REPO_OWNER"
echo "ℹ️  Repository path: $REPO_DIR"
echo "ℹ️  Home directory: $REPO_OWNER_HOME"
echo ""

# Il servizio esegue direttamente da GitHub, non serve controllare il file locale
echo "ℹ️  Il servizio eseguirà lo script direttamente da GitHub"

# Crea directory log se non esiste
if ! mkdir -p /var/log 2>/dev/null; then
    echo "⚠️  Impossibile creare directory /var/log (già esistente)"
fi

if touch /var/log/auto-git-sync.log 2>/dev/null; then
    chown "$REPO_OWNER:$REPO_OWNER" /var/log/auto-git-sync.log 2>/dev/null || echo "⚠️  Impossibile cambiare owner del log file"
    echo "✅ Log file preparato"
else
    echo "⚠️  Impossibile creare log file, verrà usato journalctl"
fi

# Crea service file personalizzato che esegue direttamente da GitHub
echo "ℹ️  Creazione service file personalizzato..."
cat > /etc/systemd/system/auto-git-sync.service << 'EOFSERVICE'
[Unit]
Description=Auto Git Sync Service
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
ExecStart=/bin/bash -c 'TEMP_SCRIPT=$(mktemp); curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/auto-git-sync.sh -o "$TEMP_SCRIPT"; bash "$TEMP_SCRIPT" PLACEHOLDER_INTERVAL; rm -f "$TEMP_SCRIPT"'
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=auto-git-sync

# Security hardening - permetti scrittura in repo (include .git)
PrivateTmp=yes
NoNewPrivileges=yes
ReadWritePaths=PLACEHOLDER_REPO /var/log/auto-git-sync.log

[Install]
WantedBy=multi-user.target
EOFSERVICE

# Sostituisci placeholder con valori reali
sed -i "s|PLACEHOLDER_USER|$REPO_OWNER|g" /etc/systemd/system/auto-git-sync.service
sed -i "s|PLACEHOLDER_GROUP|$REPO_OWNER|g" /etc/systemd/system/auto-git-sync.service
sed -i "s|PLACEHOLDER_HOME|$REPO_OWNER_HOME|g" /etc/systemd/system/auto-git-sync.service
sed -i "s|PLACEHOLDER_REPO|$REPO_DIR|g" /etc/systemd/system/auto-git-sync.service
sed -i "s|PLACEHOLDER_INTERVAL|$SYNC_INTERVAL|g" /etc/systemd/system/auto-git-sync.service

echo "✅ Service file creato e installato"

# Verifica che systemd sia disponibile
if ! command -v systemctl &> /dev/null; then
    echo "❌ systemd non disponibile su questo sistema"
    echo "   Il servizio non può essere installato"
    exit 1
fi

# Ricarica systemd
if ! systemctl daemon-reload 2>&1; then
    echo "❌ Errore durante reload di systemd"
    exit 1
fi
echo "✅ Systemd ricaricato"

# Abilita il servizio all'avvio
if ! systemctl enable auto-git-sync.service 2>&1; then
    echo "❌ Errore durante abilitazione servizio"
    exit 1
fi
echo "✅ Servizio abilitato all'avvio"

# Riavvia il servizio se già attivo
if systemctl is-active --quiet auto-git-sync.service; then
    echo "ℹ️  Servizio già attivo, riavvio in corso..."
    systemctl restart auto-git-sync.service
    echo "✅ Servizio riavviato con nuova configurazione"
fi

# Mostra menu opzioni
echo ""
echo "========================================="
echo "  Installazione Completata!"
echo "========================================="
echo ""
echo "📊 Configurazione:"
echo "   • Utente: $REPO_OWNER"
echo "   • Repository: $REPO_DIR"
echo "   • Intervallo sync: $SYNC_INTERVAL secondi"
echo ""
echo "Comandi disponibili:"
echo ""
echo "  • Avvia servizio:"
echo "    systemctl start auto-git-sync"
echo ""
echo "  • Ferma servizio:"
echo "    systemctl stop auto-git-sync"
echo ""
echo "  • Riavvia servizio:"
echo "    systemctl restart auto-git-sync"
echo ""
echo "  • Stato servizio:"
echo "    systemctl status auto-git-sync"
echo ""
echo "  • Log in tempo reale:"
echo "    journalctl -u auto-git-sync -f"
echo ""
echo "  • Log completo:"
echo "    tail -f /var/log/auto-git-sync.log"
echo ""
echo "  • Disabilita servizio:"
echo "    systemctl disable auto-git-sync"
echo ""

read -r -p "Vuoi avviare il servizio ora? (s/N): " start_now
if [[ "$start_now" =~ ^[sS]$ ]]; then
    systemctl start auto-git-sync
    echo ""
    echo "✅ Servizio avviato!"
    echo ""
    sleep 2
    systemctl status auto-git-sync --no-pager
else
    echo ""
    echo "ℹ️  Servizio non avviato. Usa 'systemctl start auto-git-sync' per avviarlo."
fi

echo ""
echo "========================================="

#!/bin/bash
# ==========================================================
#  Installazione Auto Git Sync Service
#  Installa e configura il servizio di sync automatico
#  Autore: ChatGPT per Marzio Bordin
# ==========================================================set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_FILE="auto-git-sync.sh"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
echo "========================================="
echo "  Installazione Auto Git Sync Service"
echo "========================================="
echo ""
# Verifica esecuzione come root
if [[ $EUID -ne 0 ]]; then    
echo "ÔØî Questo script deve essere eseguito come root"    
echo "   Usa: su
do bash install-auto-git-sync.sh"    exit 1fi
echo "Ô£à Esecuzione come root"
# Chiedi intervallo di sync
echo ""
echo "ÔÅ▒´©Å  Configurazione intervallo di sync"
echo ""
echo "Scegli ogni quanto eseguire il git pull:"
echo "  1) Ogni 30 secondi"
echo "  2) Ogni 1 minuto (consigliato)"
echo "  3) Ogni 5 minuti"
echo "  4) Ogni 10 minuti"
echo "  5) Ogni 30 minuti"
echo "  6) Personalizzato"
echo ""read -r -p "Scelta [2]: " interval_choicecase "$interval_choice" in    1) 
SYNC_INTERVAL=30 ;;    2|"") 
SYNC_INTERVAL=60 ;;    3) 
SYNC_INTERVAL=300 ;;    4) 
SYNC_INTERVAL=600 ;;    5) 
SYNC_INTERVAL=1800 ;;    6)        read -r -p "Inserisci intervallo in secondi: " SYNC_INTERVAL        if ! [[ "$SYNC_INTERVAL" =~ ^[0-9]+$ ]] || [ "$SYNC_INTERVAL" -lt 10 ]; then            
echo "ÔØî Valore non vali
do, uso default 60 secondi"            
SYNC_INTERVAL=60        fi        ;;    *)        
echo "ÔØî Scelta non valida, uso default 60 secondi"        
SYNC_INTERVAL=60        ;;esac
echo "Ô£à Intervallo impostato: $SYNC_INTERVAL secondi"
echo ""
# Rileva l'utente proprietario del repository
REPO_OWNER=$(stat -c '%U' "$REPO_DIR" 2>/dev/null || 
echo "root")
REPO_OWNER_HOME=$(eval 
echo "~$REPO_OWNER" 2>/dev/null || 
echo "/root")
echo "Ôä╣´©Å  Repository owner: $REPO_OWNER"
echo "Ôä╣´©Å  Repository path: $REPO_DIR"
echo "Ôä╣´©Å  Home directory: $REPO_OWNER_HOME"
echo ""
# Verifica esistenza script
if [[ ! -f "$SCRIPT_DIR/$SCRIPT_FILE" ]]; then    
echo "ÔØî File non trovato: $SCRIPT_FILE"    exit 1fi
echo "Ô£à Script trovato"
# Rendi eseguibile lo scriptchmod +x "$SCRIPT_DIR/$SCRIPT_FILE"
echo "Ô£à Permessi di esecuzione impostati"
# Crea directory log se non esistemkdir -p /var/logtouch /var/log/auto-git-sync.logchown "$REPO_OWNER:$REPO_OWNER" /var/log/auto-git-sync.log 2>/dev/null || true
echo "Ô£à Log file preparato"
# Crea service file personalizzato che esegue direttamente da GitHub
echo "Ôä╣´©Å  Creazione service file personalizzato..."cat > /etc/systemd/system/auto-git-sync.service << 'EOFSERVICE'[Unit]Description=Auto Git Sync ServiceDocumentation=https://github.com/Coverup20/checkmk-toolsAfter=network-online.targetWants=network-online.target[Service]Type=simpleUser=PLACEHOLDER_USERGroup=PLACEHOLDER_GROUPWorkingDirectory=PLACEHOLDER_HOMEEnvironment="
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"Environment="
HOME=PLACEHOLDER_HOME"ExecStart=/bin/bash -c 'bash <(curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/auto-git-sync.sh) PLACEHOLDER_INTERVAL'Restart=alwaysRestartSec=10StandardOutput=journalStandardError=journalSyslogIdentifier=auto-git-sync
# Security hardening - permetti scrittura in repo (include .git)PrivateTmp=yesNoNewPrivileges=yesReadWritePaths=PLACEHOLDER_REPO /var/log/auto-git-sync.log[Install]WantedBy=multi-user.targetEOFSERVICE
# Sostituisci placeholder con valori realised -i "s|PLACEHOLDER_USER|$REPO_OWNER|g" /etc/systemd/system/auto-git-sync.servicesed -i "s|PLACEHOLDER_GROUP|$REPO_OWNER|g" /etc/systemd/system/auto-git-sync.servicesed -i "s|PLACEHOLDER_HOME|$REPO_OWNER_HOME|g" /etc/systemd/system/auto-git-sync.servicesed -i "s|PLACEHOLDER_REPO|$REPO_DIR|g" /etc/systemd/system/auto-git-sync.servicesed -i "s|PLACEHOLDER_INTERVAL|$SYNC_INTERVAL|g" /etc/systemd/system/auto-git-sync.service
echo "Ô£à Service file creato e installato"
# Ricarica systemdsystemctl daemon-reload
echo "Ô£à Systemd ricaricato"
# Abilita il servizio all'avviosystemctl enable auto-git-sync.service
echo "Ô£à Servizio abilitato all'avvio"
# Riavvia il servizio se gi├á attivo
if systemctl is-active --quiet auto-git-sync.service; then    
echo "Ôä╣´©Å  Servizio gi├á attivo, riavvio in corso..."    systemctl restart auto-git-sync.service    
echo "Ô£à Servizio riavviato con nuova configurazione"
fi # Mostra menu opzioni
echo ""
echo "========================================="
echo "  Installazione Completata!"
echo "========================================="
echo ""
echo "­ƒôè Configurazione:"
echo "   ÔÇó Utente: $REPO_OWNER"
echo "   ÔÇó Repository: $REPO_DIR"
echo "   ÔÇó Intervallo sync: $SYNC_INTERVAL secondi"
echo ""
echo "Comandi disponibili:"
echo ""
echo "  ÔÇó Avvia servizio:"
echo "    systemctl start auto-git-sync"
echo ""
echo "  ÔÇó Ferma servizio:"
echo "    systemctl stop auto-git-sync"
echo ""
echo "  ÔÇó Riavvia servizio:"
echo "    systemctl restart auto-git-sync"
echo ""
echo "  ÔÇó Stato servizio:"
echo "    systemctl status auto-git-sync"
echo ""
echo "  ÔÇó Log in tempo reale:"
echo "    journalctl -u auto-git-sync -f"
echo ""
echo "  ÔÇó Log completo:"
echo "    tail -f /var/log/auto-git-sync.log"
echo ""
echo "  ÔÇó Disabilita servizio:"
echo "    systemctl disable auto-git-sync"
echo ""read -r -p "Vuoi avviare il servizio ora? (s/N): " start_now
if [[ "$start_now" =~ ^[sS]$ ]]; then    systemctl start auto-git-sync    
echo ""    
echo "Ô£à Servizio avviato!"    
echo ""    sleep 2    systemctl status auto-git-sync --no-pager
else    
echo ""    
echo "Ôä╣´©Å  Servizio non avviato. Usa 'systemctl start auto-git-sync' per avviarlo."fi
echo ""
echo "========================================="

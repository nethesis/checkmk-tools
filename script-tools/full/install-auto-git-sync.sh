
#!/bin/bash
/bin/bash
# ==========================================================
#  Installazione Auto Git Sync Service
#  Installa e configura il servizio di sync automatico
#  Autore: ChatGPT per Marzio Bordin
# ==========================================================set -e
# Funzione per installare gitinstall_git() {    
echo "Ôä╣´©Å  Git non trovato, installazione in corso..."    if command -v apt-get &> /dev/null; then        timeout 300 apt-get update -qq && timeout 300 apt-get install -y git || {            
echo "ÔØî Timeout durante installazione git"            exit 1        }    elif command -v yum &> /dev/null; then        timeout 300 yum install -y git || {            
echo "ÔØî Timeout durante installazione git"            exit 1        }    elif command -v dnf &> /dev/null; then        timeout 300 dnf install -y git || {            
echo "ÔØî Timeout durante installazione git"            exit 1        }    else        
echo "ÔØî Package manager non supportato. Installa git manualmente:"        
echo "   - Debian/Ubuntu: apt-get install git"        
echo "   - CentOS/RHEL: yum install git"        exit 1    fi    
echo "Ô£à Git installato"}
# Verifica se git ├¿ installatoif ! command -v git &> /dev/null; then    install_gitfi
# Cerca il repository checkmk-tools
# Priorit├á: /opt, poi /root, poi $HOMEif [[ -d "/opt/checkmk-tools/.git" ]]; then    
REPO_DIR="/opt/checkmk-tools"elif [[ -d "/root/checkmk-tools/.git" ]]; then    
REPO_DIR="/root/checkmk-tools"elif [[ -d "$HOME/checkmk-tools/.git" ]]; then    
REPO_DIR="$HOME/checkmk-tools"else    
echo "ÔØî Repository checkmk-tools non trovato"    
echo "   Posizioni cercate:"    
echo "   - /opt/checkmk-tools (consigliato)"    
echo "   - /root/checkmk-tools"    
echo "   - $HOME/checkmk-tools"    
echo ""    
echo "Ôä╣´©Å  Se vuoi clonare il repository in /opt/checkmk-tools:"    
echo "   cd /opt && git clone https://github.com/Coverup20/checkmk-tools.git"    
echo ""    read -r -p "Inserisci il path del repository [/opt/checkmk-tools]: " REPO_DIR    
REPO_DIR="${REPO_DIR:-/opt/checkmk-tools}"        
# Se non esiste, offre di clonarlo    if [[ ! -d "$REPO_DIR/.git" ]]; then        read -r -p "Repository non trovato. Vuoi clonarlo in $REPO_DIR? [S/n]: " clone_choice        if [[ "$clone_choice" =~ ^[Nn] ]]; then            
echo "ÔØî Installazione annullata"            exit 1        fi                
# Crea directory parent se non esiste        
PARENT_DIR=$(dirname "$REPO_DIR")        mkdir -p "$PARENT_DIR"                
echo "­ƒôÑ Clonazione repository in $REPO_DIR..."        if ! timeout 120 git clone https://github.com/Coverup20/checkmk-tools.git "$REPO_DIR" 2>&1; then            
echo "ÔØî Errore durante la clonazione (timeout o errore rete)"            exit 1        fi                
# Verifica che il clone sia riuscito        if [[ ! -d "$REPO_DIR/.git" ]]; then            
echo "ÔØî Repository clonato ma .git non trovato"            exit 1        fi                
echo "Ô£à Repository clonato con successo"    fifi
echo "========================================="
echo "  Installazione Auto Git Sync Service"
echo "========================================="
echo ""
# Verifica esecuzione come rootif [[ $EUID -ne 0 ]]; then    
echo "ÔØî Questo script deve essere eseguito come root"    
echo "   Usa: sudo bash install-auto-git-sync.sh"    exit 1fi
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
SYNC_INTERVAL=1800 ;;    6)        read -r -p "Inserisci intervallo in secondi (10-3600): " SYNC_INTERVAL        if ! [[ "$SYNC_INTERVAL" =~ ^[0-9]+$ ]] || [ "$SYNC_INTERVAL" -lt 10 ] || [ "$SYNC_INTERVAL" -gt 3600 ]; then            
echo "ÔØî Valore non valido (deve essere tra 10 e 3600), uso default 60 secondi"            
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
# Il servizio esegue direttamente da GitHub, non serve controllare il file locale
echo "Ôä╣´©Å  Il servizio eseguir├á lo script direttamente da GitHub"
# Crea directory log se non esisteif ! mkdir -p /var/log 2>/dev/null; then    
echo "ÔÜá´©Å  Impossibile creare directory /var/log (gi├á esistente)"fiif touch /var/log/auto-git-sync.log 2>/dev/null; then    chown "$REPO_OWNER:$REPO_OWNER" /var/log/auto-git-sync.log 2>/dev/null || 
echo "ÔÜá´©Å  Impossibile cambiare owner del log file"    
echo "Ô£à Log file preparato"else    
echo "ÔÜá´©Å  Impossibile creare log file, verr├á usato journalctl"fi
# Crea service file personalizzato che esegue direttamente da GitHub
echo "Ôä╣´©Å  Creazione service file personalizzato..."cat > /etc/systemd/system/auto-git-sync.service << 'EOFSERVICE'[Unit]Description=Auto Git Sync ServiceDocumentation=https://github.com/Coverup20/checkmk-toolsAfter=network-online.targetWants=network-online.target[Service]Type=simpleUser=PLACEHOLDER_USERGroup=PLACEHOLDER_GROUPWorkingDirectory=PLACEHOLDER_HOMEEnvironment="
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"Environment="
HOME=PLACEHOLDER_HOME"ExecStart=/bin/bash -c '
TEMP_SCRIPT=$(mktemp); curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/auto-git-sync.sh -o "$TEMP_SCRIPT"; bash "$TEMP_SCRIPT" PLACEHOLDER_INTERVAL; rm -f "$TEMP_SCRIPT"'Restart=alwaysRestartSec=10StandardOutput=journalStandardError=journalSyslogIdentifier=auto-git-sync
# Security hardening - permetti scrittura in repo (include .git)PrivateTmp=yesNoNewPrivileges=yesReadWritePaths=PLACEHOLDER_REPO /var/log/auto-git-sync.log[Install]WantedBy=multi-user.targetEOFSERVICE
# Sostituisci placeholder con valori realised -i "s|PLACEHOLDER_USER|$REPO_OWNER|g" /etc/systemd/system/auto-git-sync.servicesed -i "s|PLACEHOLDER_GROUP|$REPO_OWNER|g" /etc/systemd/system/auto-git-sync.servicesed -i "s|PLACEHOLDER_HOME|$REPO_OWNER_HOME|g" /etc/systemd/system/auto-git-sync.servicesed -i "s|PLACEHOLDER_REPO|$REPO_DIR|g" /etc/systemd/system/auto-git-sync.servicesed -i "s|PLACEHOLDER_INTERVAL|$SYNC_INTERVAL|g" /etc/systemd/system/auto-git-sync.service
echo "Ô£à Service file creato e installato"
# Verifica che systemd sia disponibileif ! command -v systemctl &> /dev/null; then    
echo "ÔØî systemd non disponibile su questo sistema"    
echo "   Il servizio non pu├▓ essere installato"    exit 1fi
# Ricarica systemdif ! systemctl daemon-reload 2>&1; then    
echo "ÔØî Errore durante reload di systemd"    exit 1fi
echo "Ô£à Systemd ricaricato"
# Abilita il servizio all'avvioif ! systemctl enable auto-git-sync.service 2>&1; then    
echo "ÔØî Errore durante abilitazione servizio"    exit 1fi
echo "Ô£à Servizio abilitato all'avvio"
# Riavvia il servizio se gi├á attivoif systemctl is-active --quiet auto-git-sync.service; then    
echo "Ôä╣´©Å  Servizio gi├á attivo, riavvio in corso..."    systemctl restart auto-git-sync.service    
echo "Ô£à Servizio riavviato con nuova configurazione"fi
# Mostra menu opzioni
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
echo ""read -r -p "Vuoi avviare il servizio ora? (s/N): " start_nowif [[ "$start_now" =~ ^[sS]$ ]]; then    systemctl start auto-git-sync    
echo ""    
echo "Ô£à Servizio avviato!"    
echo ""    sleep 2    systemctl status auto-git-sync --no-pagerelse    
echo ""    
echo "Ôä╣´©Å  Servizio non avviato. Usa 'systemctl start auto-git-sync' per avviarlo."fi
echo ""
echo "========================================="

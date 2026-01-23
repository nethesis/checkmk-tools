#!/bin/bash
set -euo pipefail

### SCRIPT INTERATTIVO RESTORE DISASTER RECOVERY ###

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

RCLONE_REMOTE="${RCLONE_REMOTE:-do:testmonbck}"
BACKUP_BASE="/opt/checkmk-backup"
TMP_DIR="$BACKUP_BASE/tmp"

### FUNZIONI UTILITY ###
log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"; }
success() { echo -e "${GREEN}✅ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
error() { echo -e "${RED}❌ $*${NC}" >&2; }
title() { echo -e "\n${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"; echo -e "${CYAN}║ $*${NC}"; echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}\n"; }

confirm() {
  local prompt="$1"
  local default="${2:-n}"
  local reply
  
  if [[ "$default" == "y" ]]; then
    read -p "$prompt [Y/n] " -r reply
    reply="${reply:-y}"
  else
    read -p "$prompt [y/N] " -r reply
    reply="${reply:-n}"
  fi
  
  [[ "$reply" =~ ^[Yy]$ ]]
}

pause() {
  echo ""
  read -p "Premi INVIO per continuare..." -r
}

### CHECK ROOT ###
if [[ $EUID -ne 0 ]]; then
  error "Questo script deve essere eseguito come root"
  echo "  Usa: sudo $0"
  exit 1
fi

### BANNER ###
clear
title "🔄 CHECKMK DISASTER RECOVERY - RESTORE INTERATTIVO"

echo -e "${YELLOW}ATTENZIONE:${NC}"
echo "Questo script ripristinerà la configurazione CheckMK da backup."
echo "Il sito verrà fermato durante l'operazione."
echo ""

if ! confirm "Vuoi continuare?" "n"; then
  error "Operazione annullata dall'utente"
  exit 0
fi

### VERIFICA RCLONE ###
title "📡 Verifica Connessione Storage Remoto"

if ! command -v rclone >/dev/null; then
  error "rclone non installato!"
  echo ""
  echo "Installalo con:"
  echo "  curl https://rclone.org/install.sh | sudo bash"
  exit 1
fi

log "Verifica connessione a $RCLONE_REMOTE..."
if ! rclone lsd "$RCLONE_REMOTE:" >/dev/null 2>&1; then
  error "Impossibile connettersi a $RCLONE_REMOTE"
  echo ""
  echo "Verifica configurazione rclone:"
  echo "  rclone config"
  exit 1
fi
success "Connessione OK"

### SELEZIONE SITE ###
title "🏢 Selezione Site CheckMK"

log "Sites disponibili sul sistema:"
omd sites | tail -n +2 || true
echo ""

read -p "Nome del site da ripristinare: " SITE
SITE="${SITE:-monitoring}"
SITE_BASE="/opt/omd/sites/$SITE"

if [[ ! -d "$SITE_BASE" ]]; then
  error "Site '$SITE' non trovato in $SITE_BASE"
  echo ""
  echo "Crea prima il site con:"
  echo "  omd create $SITE"
  exit 1
fi

success "Site '$SITE' trovato"

### LISTA BACKUP DISPONIBILI ###
title "📦 Backup Disponibili"

RCLONE_PATH="checkmk-dr-backup/$SITE"
log "Recupero lista backup da $RCLONE_REMOTE:$RCLONE_PATH..."

BACKUP_LIST=$(mktemp)
if ! rclone lsf "$RCLONE_REMOTE:$RCLONE_PATH" --format "tp" | grep "\.tgz$" | sort -r > "$BACKUP_LIST"; then
  error "Nessun backup trovato per site '$SITE'"
  rm -f "$BACKUP_LIST"
  exit 1
fi

if [[ ! -s "$BACKUP_LIST" ]]; then
  error "Nessun backup trovato per site '$SITE'"
  rm -f "$BACKUP_LIST"
  exit 1
fi

echo ""
echo "Backup disponibili:"
echo ""
i=1
declare -A BACKUP_MAP
while IFS=$'\t' read -r mtime filename; do
  BACKUP_MAP[$i]="$filename"
  BACKUP_DATE=$(date -d "$mtime" "+%d/%m/%Y %H:%M" 2>/dev/null || echo "$mtime")
  printf "%2d) %s  [%s]\n" "$i" "$filename" "$BACKUP_DATE"
  ((i++))
done < "$BACKUP_LIST"

echo ""
read -p "Seleziona numero backup (1-$((i-1))) o 'q' per uscire: " selection

if [[ "$selection" == "q" ]]; then
  rm -f "$BACKUP_LIST"
  error "Operazione annullata"
  exit 0
fi

if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -ge "$i" ]]; then
  rm -f "$BACKUP_LIST"
  error "Selezione non valida"
  exit 1
fi

BACKUP_FILE="${BACKUP_MAP[$selection]}"
rm -f "$BACKUP_LIST"

success "Selezionato: $BACKUP_FILE"

### SCARICA METADATA ###
title "📋 Informazioni Backup"

METADATA_FILE="${BACKUP_FILE%.tgz}.metadata.txt"
mkdir -p "$TMP_DIR"

if rclone lsf "$RCLONE_REMOTE:$RCLONE_PATH/$METADATA_FILE" >/dev/null 2>&1; then
  log "Scarico metadati..."
  rclone copy "$RCLONE_REMOTE:$RCLONE_PATH/$METADATA_FILE" "$TMP_DIR/" -q
  
  if [[ -f "$TMP_DIR/$METADATA_FILE" ]]; then
    echo ""
    cat "$TMP_DIR/$METADATA_FILE"
    echo ""
  fi
else
  warn "File metadati non trovato (backup vecchio?)"
fi

pause

### CONFERMA FINALE ###
title "⚠️  CONFERMA RIPRISTINO"

echo -e "${RED}ATTENZIONE:${NC}"
echo "Stai per ripristinare:"
echo "  - Site: $SITE"
echo "  - Backup: $BACKUP_FILE"
echo ""
echo "Operazioni che verranno eseguite:"
echo "  1. Fermo site CheckMK"
echo "  2. Backup configurazione attuale (precauzione)"
echo "  3. Estrazione backup DR"
echo "  4. Ripristino permessi"
echo "  5. Riavvio site"
echo ""

if ! confirm "Sei SICURO di voler procedere?" "n"; then
  error "Operazione annullata"
  exit 0
fi

### DOWNLOAD BACKUP ###
title "⬇️  Download Backup"

log "Scarico $BACKUP_FILE da storage remoto..."
rclone copy "$RCLONE_REMOTE:$RCLONE_PATH/$BACKUP_FILE" "$TMP_DIR/" --progress

if [[ ! -f "$TMP_DIR/$BACKUP_FILE" ]]; then
  error "Download fallito!"
  exit 1
fi

BACKUP_SIZE=$(du -h "$TMP_DIR/$BACKUP_FILE" | cut -f1)
success "Download completato ($BACKUP_SIZE)"

# Verifica integrità
log "Verifica integrità archivio..."
if ! tar tzf "$TMP_DIR/$BACKUP_FILE" >/dev/null 2>&1; then
  error "Archivio corrotto!"
  exit 1
fi
success "Archivio integro"

### FERMA SITE ###
title "🛑 Fermo Site CheckMK"

log "Fermo site '$SITE'..."
if omd stop "$SITE" 2>&1 | tee /tmp/omd_stop.log; then
  success "Site fermato"
else
  warn "Alcuni servizi potrebbero non essere stati fermati correttamente"
  cat /tmp/omd_stop.log
  if ! confirm "Vuoi continuare comunque?"; then
    error "Operazione annullata"
    exit 1
  fi
fi

### BACKUP CONFIGURAZIONE ATTUALE ###
title "💾 Backup Configurazione Attuale"

BACKUP_OLD="$BACKUP_BASE/pre-restore-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_OLD"

log "Salvo configurazione attuale in $BACKUP_OLD..."
tar czf "$BACKUP_OLD/etc-backup.tgz" -C "$SITE_BASE" etc 2>/dev/null || true
tar czf "$BACKUP_OLD/local-backup.tgz" -C "$SITE_BASE" local 2>/dev/null || true

success "Backup di sicurezza creato"
echo "  In caso di problemi: $BACKUP_OLD"

### ESTRAZIONE BACKUP ###
title "📂 Ripristino Configurazione"

log "Estraggo backup in $SITE_BASE..."
if tar xzf "$TMP_DIR/$BACKUP_FILE" -C "$SITE_BASE" 2>&1 | tee /tmp/tar_extract.log; then
  success "Estrazione completata"
else
  error "Errore durante l'estrazione!"
  cat /tmp/tar_extract.log
  echo ""
  error "ROLLBACK: Ripristino backup precedente..."
  tar xzf "$BACKUP_OLD/etc-backup.tgz" -C "$SITE_BASE" 2>/dev/null || true
  tar xzf "$BACKUP_OLD/local-backup.tgz" -C "$SITE_BASE" 2>/dev/null || true
  exit 1
fi

### RIPRISTINO PERMESSI ###
title "🔐 Ripristino Permessi"

log "Ripristino ownership per user '$SITE'..."
chown -R "$SITE:$SITE" "$SITE_BASE"
success "Permessi ripristinati"

### RIAVVIO SITE ###
title "▶️  Riavvio Site CheckMK"

log "Riavvio site '$SITE'..."
if omd start "$SITE" 2>&1 | tee /tmp/omd_start.log; then
  success "Site riavviato"
else
  error "Errore durante il riavvio!"
  cat /tmp/omd_start.log
  echo ""
  warn "Verifica log manualmente:"
  echo "  omd status $SITE"
  echo "  tail -f /opt/omd/sites/$SITE/var/log/*.log"
fi

echo ""
log "Stato servizi:"
omd status "$SITE"

### VERIFICA SERVIZI ###
title "✅ Verifica Servizi"

log "Attendo avvio servizi..."
sleep 5

FAILED=0
while IFS= read -r line; do
  if echo "$line" | grep -q "stopped" || echo "$line" | grep -q "STOPPED"; then
    warn "$line"
    ((FAILED++))
  fi
done < <(omd status "$SITE" 2>&1)

if [[ $FAILED -gt 0 ]]; then
  warn "$FAILED servizio/i non avviato/i"
  echo ""
  echo "Verifica manualmente con:"
  echo "  omd status $SITE"
  echo "  omd start $SITE"
else
  success "Tutti i servizi sono attivi"
fi

### RICOMPILA CONFIGURAZIONE ###
title "🔄 Ricompilazione Configurazione"

if confirm "Vuoi ricompilare la configurazione monitoring?"; then
  log "Ricompilo configurazione..."
  su - "$SITE" -c "cmk -R" 2>&1 | head -20
  su - "$SITE" -c "cmk -O" 2>&1 | head -20
  success "Configurazione ricompilata"
fi

### REINSTALLA YDEA-TOOLKIT ###
title "🎫 Reinstallazione Componenti Esterni"

echo "Il backup non include cronjobs e configurazione /opt/ydea-toolkit"
echo ""
if confirm "Vuoi reinstallare integrazione Ydea-Toolkit ora?"; then
  log "Scarico e installo ydea-toolkit..."
  export CHECKMK_SITE="$SITE"
  curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/Ydea-Toolkit/full/install-ydea-checkmk-integration.sh | bash
  success "Integrazione Ydea installata"
else
  warn "Ricorda di reinstallare manualmente con:"
  echo "  export CHECKMK_SITE=$SITE"
  echo "  curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/Ydea-Toolkit/full/install-ydea-checkmk-integration.sh | bash"
fi

echo ""
if confirm "Vuoi reinstallare cronjob cleanup CheckMK?"; then
  (crontab -l 2>/dev/null; echo "# Cleanup Nagios & PNP4Nagios"; echo "0 3 * * * curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/cleanup-checkmk-retention.sh | bash >> /var/log/cleanup-checkmk.log 2>&1") | crontab -
  success "Cronjob cleanup installato"
fi

### CLEANUP ###
rm -f "$TMP_DIR/$BACKUP_FILE" "$TMP_DIR/$METADATA_FILE"

### RIEPILOGO FINALE ###
title "🎉 RESTORE COMPLETATO!"

success "Ripristino eseguito con successo"
echo ""
echo "📊 Riepilogo:"
echo "  - Site: $SITE"
echo "  - Backup: $BACKUP_FILE"
echo "  - Backup precedente salvato in: $BACKUP_OLD"
echo ""
echo "🔍 Prossimi passi:"
echo ""
echo "1. Verifica web interface:"
echo "   https://$(hostname)/$SITE/"
echo ""
echo "2. Controlla log:"
echo "   tail -f /opt/omd/sites/$SITE/var/log/cmc.log"
echo "   tail -f /opt/omd/sites/$SITE/var/log/web.log"
echo ""
echo "3. Verifica hosts:"
echo "   su - $SITE"
echo "   cmk --list-hosts"
echo ""
echo "4. Configura credenziali Ydea (se necessario):"
echo "   nano /opt/ydea-toolkit/.env"
echo ""
echo -e "${GREEN}✅ Restore completato!${NC}"
echo ""

exit 0

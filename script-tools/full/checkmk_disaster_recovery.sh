#!/bin/bash
set -euo pipefail

### CHECKMK DISASTER RECOVERY ###
# Script completo per disaster recovery CheckMK:
# 1. Lista backup disponibili su cloud (job00-daily o job01-weekly)
# 2. Download backup selezionato
# 3. Restore automatico (con decompressione se necessario)
# 4. Verifica servizi
#
# Uso: ./checkmk_disaster_recovery.sh

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

RCLONE_REMOTE="${RCLONE_REMOTE:-do:testmonbck}"
DOWNLOAD_DIR="/var/backups/checkmk/disaster-recovery"

### FUNZIONI UTILITY ###
log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"; }
success() { echo -e "${GREEN}✅ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
error() { echo -e "${RED}❌ $*${NC}" >&2; exit 1; }
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

### CHECK ROOT ###
if [[ $EUID -ne 0 ]]; then
  error "Questo script deve essere eseguito come root"
fi

### BANNER ###
clear
title "🚨 CHECKMK DISASTER RECOVERY 🚨"

echo ""
echo "Questo script eseguirà:"
echo "  1️⃣  Lista backup disponibili su cloud"
echo "  2️⃣  Download backup selezionato"
echo "  3️⃣  Restore automatico del backup"
echo "  4️⃣  Verifica stato servizi CheckMK"
echo ""
warn "⚠️  ATTENZIONE: Questa operazione RIMUOVERÀ il site esistente!"
echo ""

if ! confirm "Vuoi procedere con il disaster recovery?" "n"; then
  error "Operazione annullata dall'utente"
fi

### VERIFICA/INSTALLA RCLONE ###
title "📦 Verifica rclone"

if ! command -v rclone >/dev/null; then
  warn "rclone non installato"
  if confirm "Vuoi installarlo ora?" "y"; then
    log "Installo rclone..."
    curl -fsSL https://rclone.org/install.sh | bash || error "Installazione rclone fallita"
    success "rclone installato"
  else
    error "rclone necessario per disaster recovery"
  fi
else
  success "rclone già installato"
fi

### CONFIGURAZIONE RCLONE ###
title "⚙️  Configurazione rclone"

RCLONE_CONF=""
if [[ -f "/root/.config/rclone/rclone.conf" ]]; then
  RCLONE_CONF="/root/.config/rclone/rclone.conf"
elif [[ -f "/opt/omd/sites/monitoring/.config/rclone/rclone.conf" ]]; then
  RCLONE_CONF="/opt/omd/sites/monitoring/.config/rclone/rclone.conf"
fi

if [[ -z "$RCLONE_CONF" ]] || [[ ! -f "$RCLONE_CONF" ]]; then
  error "Configurazione rclone non trovata. Configura prima rclone: rclone config"
fi

success "Configurazione rclone: $RCLONE_CONF"

# Test connessione
log "Test connessione rclone..."
if ! rclone lsd "$RCLONE_REMOTE" --config="$RCLONE_CONF" --s3-no-check-bucket >/dev/null 2>&1; then
  error "Connessione rclone fallita. Verifica configurazione: rclone config"
fi
success "Connessione rclone OK"

### SELEZIONE JOB ###
title "🗂️  Selezione Job"

echo "Quale tipo di backup vuoi ripristinare?"
echo ""
echo "  1) 📦 job00-daily  - Backup compressi giornalieri (1.2M, retention 90)"
echo "  2) 📦 job01-weekly - Backup completi settimanali (362M, retention 5)"
echo ""
read -p "Selezione [1-2]: " JOB_CHOICE

case $JOB_CHOICE in
  1)
    RCLONE_PATH="checkmk-backups/job00-daily"
    IS_COMPRESSED=true
    log "Selezionato job00-daily (backup compressi)"
    ;;
  2)
    RCLONE_PATH="checkmk-backups/job01-weekly"
    IS_COMPRESSED=false
    log "Selezionato job01-weekly (backup completi)"
    ;;
  *)
    error "Selezione non valida"
    ;;
esac

### LISTA BACKUP DISPONIBILI ###
title "📦 Backup Disponibili"

log "Recupero lista da $RCLONE_REMOTE/$RCLONE_PATH..."

# Lista directory (backup CheckMK)
BACKUP_DIRS=$(rclone lsd "$RCLONE_REMOTE/$RCLONE_PATH" --config="$RCLONE_CONF" --s3-no-check-bucket 2>/dev/null | awk '{print $5}' | sort -r)

if [[ -z "$BACKUP_DIRS" ]]; then
  error "Nessun backup trovato in $RCLONE_REMOTE/$RCLONE_PATH"
fi

echo ""
echo "Backup disponibili (ordinati per data, più recenti prima):"
echo ""
i=1
declare -A BACKUP_MAP

while IFS= read -r dirname; do
  [[ -z "$dirname" ]] && continue
  BACKUP_MAP[$i]="$dirname"
  
  # Estrai timestamp dal nome se presente
  TIMESTAMP=""
  if [[ "$dirname" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}h[0-9]{2}) ]]; then
    TIMESTAMP=" [${BASH_REMATCH[1]}]"
  fi
  
  printf "%2d) 📁 %-60s%s\n" "$i" "$dirname" "$TIMESTAMP"
  ((i++))
done <<< "$BACKUP_DIRS"

echo ""
read -p "Seleziona backup da ripristinare [1-$((i-1))]: " SELECTION

if [[ ! "$SELECTION" =~ ^[0-9]+$ ]] || [[ "$SELECTION" -lt 1 ]] || [[ "$SELECTION" -ge "$i" ]]; then
  error "Selezione non valida"
fi

SELECTED_BACKUP="${BACKUP_MAP[$SELECTION]}"
success "Selezionato: $SELECTED_BACKUP"

### ESTRAI SITE NAME DAL BACKUP ###
# Formato: Check_MK-monitor-monitoring-job00-complete-2026-01-27-16h30
# Site name: monitoring
if [[ "$SELECTED_BACKUP" =~ Check_MK-[^-]+-([^-]+)- ]]; then
  SITE_NAME="${BASH_REMATCH[1]}"
else
  error "Impossibile estrarre site name da: $SELECTED_BACKUP"
fi

log "Site name rilevato: $SITE_NAME"

### CONFERMA OPERAZIONE ###
title "⚠️  CONFERMA DISASTER RECOVERY"

echo ""
echo "ATTENZIONE! Stai per eseguire:"
echo ""
echo "  📥 Download:  $SELECTED_BACKUP"
echo "  📂 Da:        $RCLONE_REMOTE/$RCLONE_PATH/"
echo "  💾 Tipo:      $([ "$IS_COMPRESSED" = true ] && echo "Backup compresso (job00)" || echo "Backup completo (job01)")"
echo "  🎯 Site:      $SITE_NAME"
echo "  ⚠️  Azione:   RIMOZIONE e RESTORE completo del site"
echo ""
warn "Il site '$SITE_NAME' verrà COMPLETAMENTE RIMOSSO e RIPRISTINATO!"
echo ""

if ! confirm "Confermi disaster recovery?" "n"; then
  error "Operazione annullata dall'utente"
fi

### PREPARAZIONE DIRECTORY ###
title "📂 Preparazione Directory Download"

mkdir -p "$DOWNLOAD_DIR"
log "Directory download: $DOWNLOAD_DIR"

# Pulisci eventuali download precedenti
if [[ -d "$DOWNLOAD_DIR/$SELECTED_BACKUP" ]]; then
  log "Rimuovo download precedente..."
  rm -rf "$DOWNLOAD_DIR/$SELECTED_BACKUP"
fi

### DOWNLOAD BACKUP ###
title "📥 Download Backup"

log "Scarico $SELECTED_BACKUP..."
log "Questo potrebbe richiedere alcuni minuti..."

if ! rclone copy "$RCLONE_REMOTE/$RCLONE_PATH/$SELECTED_BACKUP" "$DOWNLOAD_DIR/$SELECTED_BACKUP" \
  --config="$RCLONE_CONF" \
  --s3-no-check-bucket \
  --progress; then
  error "Download fallito"
fi

# Verifica download
if [[ ! -d "$DOWNLOAD_DIR/$SELECTED_BACKUP" ]]; then
  error "Directory backup non trovata dopo download"
fi

BACKUP_TARFILE="$DOWNLOAD_DIR/$SELECTED_BACKUP/site-$SITE_NAME.tar.gz"
if [[ ! -f "$BACKUP_TARFILE" ]]; then
  error "File backup non trovato: $BACKUP_TARFILE"
fi

BACKUP_SIZE=$(du -h "$BACKUP_TARFILE" | cut -f1)
success "Download completato ($BACKUP_SIZE)"

### STOP SITE ESISTENTE ###
title "⏸️  Stop Site Esistente"

if omd sites | grep -q "^$SITE_NAME "; then
  warn "Site '$SITE_NAME' esistente rilevato"
  log "Fermo il site..."
  omd stop "$SITE_NAME" 2>/dev/null || true
  success "Site fermato"
else
  log "Nessun site esistente da fermare"
fi

### RIMOZIONE SITE ESISTENTE ###
title "🗑️  Rimozione Site Esistente"

if omd sites | grep -q "^$SITE_NAME "; then
  warn "Rimuovo site esistente '$SITE_NAME'..."
  if ! omd rm --kill "$SITE_NAME"; then
    error "Rimozione site fallita"
  fi
  success "Site rimosso"
else
  log "Nessun site da rimuovere"
fi

### RESTORE BACKUP ###
title "🔄 Restore Backup"

log "Ripristino backup da $BACKUP_TARFILE..."

if ! omd restore "$BACKUP_TARFILE"; then
  error "omd restore fallito"
fi

success "Backup ripristinato"

### CREAZIONE DIRECTORY MANCANTI ###
if [ "$IS_COMPRESSED" = true ]; then
  title "📁 Creazione Directory Mancanti (Backup Compresso)"
  
  SITE_DIR="/opt/omd/sites/$SITE_NAME"
  
  # Directory critiche per backup compressi
  REQUIRED_DIRS=(
    "$SITE_DIR/var/nagios"
    "$SITE_DIR/var/nagios/rrd"
    "$SITE_DIR/var/log/apache"
    "$SITE_DIR/var/log/nagios"
    "$SITE_DIR/var/log/agent-receiver"
    "$SITE_DIR/var/check_mk/crashes"
    "$SITE_DIR/var/check_mk/inventory_archive"
    "$SITE_DIR/var/check_mk/logwatch"
    "$SITE_DIR/var/check_mk/wato/snapshots"
    "$SITE_DIR/var/check_mk/wato/log"
    "$SITE_DIR/var/tmp"
    "$SITE_DIR/tmp"
  )
  
  for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
      log "  Creo: $dir"
      mkdir -p "$dir"
    fi
  done
  
  success "Directory create"
  
  ### CORREZIONE OWNERSHIP ###
  title "🔧 Correzione Ownership e Permessi"
  
  log "Correggo ownership ricorsivo..."
  chown -R "$SITE_NAME:$SITE_NAME" "$SITE_DIR/var/log" 2>/dev/null || true
  chown -R "$SITE_NAME:$SITE_NAME" "$SITE_DIR/var/nagios" 2>/dev/null || true
  chown -R "$SITE_NAME:$SITE_NAME" "$SITE_DIR/var/check_mk" 2>/dev/null || true
  chown -R "$SITE_NAME:$SITE_NAME" "$SITE_DIR/var/tmp" "$SITE_DIR/tmp" 2>/dev/null || true
  
  log "Correggo permessi directory sensibili..."
  chmod 750 "$SITE_DIR/var/log/apache" 2>/dev/null || true
  chmod 755 "$SITE_DIR/var/log/nagios" 2>/dev/null || true
  chmod 755 "$SITE_DIR/var/nagios" 2>/dev/null || true
  
  success "Ownership e permessi corretti"
fi

### AVVIO SITE ###
title "🚀 Avvio Site"

log "Avvio site '$SITE_NAME'..."

if ! omd start "$SITE_NAME"; then
  error "Avvio site fallito. Controlla i log in /opt/omd/sites/$SITE_NAME/var/log/"
fi

success "Site avviato"

### VERIFICA STATUS ###
title "✅ Verifica Status Finale"

echo ""
omd status "$SITE_NAME"

### RIEPILOGO FINALE ###
echo ""
title "🎉 DISASTER RECOVERY COMPLETATO!"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    RIEPILOGO OPERAZIONE                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "  ✅ Backup:      $SELECTED_BACKUP"
echo "  ✅ Tipo:        $([ "$IS_COMPRESSED" = true ] && echo "Compresso (job00-daily)" || echo "Completo (job01-weekly)")"
echo "  ✅ Site:        $SITE_NAME"
echo "  ✅ Dimensione:  $BACKUP_SIZE"
echo "  ✅ Status:      RUNNING"
echo ""
echo "  🌐 Web UI:      http://$(hostname)/$SITE_NAME/"
echo "  📁 Site dir:    /opt/omd/sites/$SITE_NAME"
echo "  📋 Logs:        /opt/omd/sites/$SITE_NAME/var/log/"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                      PROSSIMI PASSI                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "  1. Accedi alla Web UI e verifica la configurazione"
echo "  2. Controlla che tutti gli host siano monitorati correttamente"
echo "  3. Verifica le notifiche email/telegram"
echo "  4. Rimuovi backup temporaneo: rm -rf $DOWNLOAD_DIR"
echo ""

success "Disaster recovery completato con successo! 🎉"

exit 0

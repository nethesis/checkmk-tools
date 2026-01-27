#!/bin/bash
set -euo pipefail

### SCRIPT DOWNLOAD BACKUP DA DIGITALOCEAN SPACES ###

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

RCLONE_REMOTE="${RCLONE_REMOTE:-do:testmonbck}"
DOWNLOAD_DIR="/var/backups/checkmk"

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

### CHECK ROOT ###
if [[ $EUID -ne 0 ]]; then
  error "Questo script deve essere eseguito come root"
  echo "  Usa: sudo $0"
  exit 1
fi

### BANNER ###
clear
title "📥 DOWNLOAD BACKUP DA DIGITALOCEAN SPACES"

### VERIFICA/INSTALLA RCLONE ###
title "📦 Verifica rclone"

if ! command -v rclone >/dev/null; then
  warn "rclone non installato"
  if confirm "Vuoi installarlo ora?" "y"; then
    log "Installo rclone..."
    if curl -fsSL https://rclone.org/install.sh | bash; then
      success "rclone installato"
    else
      error "Installazione rclone fallita"
      exit 1
    fi
  else
    error "rclone necessario per scaricare i backup"
    exit 1
  fi
else
  success "rclone già installato"
fi

### SELEZIONE DESTINAZIONE DOWNLOAD ###
title "📂 Destinazione Download"

read -p "Directory download [/tmp/checkmk-backups]: " DOWNLOAD_DIR
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/tmp/checkmk-backups}"

mkdir -p "$DOWNLOAD_DIR"
log "Directory download: $DOWNLOAD_DIR"

### CONFIGURAZIONE RCLONE ###
title "⚙️  Configurazione rclone"

# Cerca configurazione rclone in ordine di priorità
RCLONE_CONF=""
if [[ -f "/root/.config/rclone/rclone.conf" ]]; then
  RCLONE_CONF="/root/.config/rclone/rclone.conf"
elif [[ -f "/opt/omd/sites/monitoring/.config/rclone/rclone.conf" ]]; then
  RCLONE_CONF="/opt/omd/sites/monitoring/.config/rclone/rclone.conf"
fi

if [[ -z "$RCLONE_CONF" ]] || [[ ! -f "$RCLONE_CONF" ]]; then
  warn "Configurazione rclone non trovata"
  echo "  Cercato in: /root/.config/rclone/rclone.conf"
  echo "              /opt/omd/sites/monitoring/.config/rclone/rclone.conf"
  echo ""
  
  if confirm "Vuoi configurare rclone ora per DigitalOcean Spaces?" "y"; then
    
    # Crea directory config root
    mkdir -p /root/.config/rclone
    RCLONE_CONF="/root/.config/rclone/rclone.conf"
    
    echo "Inserisci le credenziali DigitalOcean Spaces:"
    echo ""
    read -p "Access Key ID: " ACCESS_KEY
    read -sp "Secret Access Key: " SECRET_KEY
    echo ""
    read -p "Region [ams3]: " REGION
    REGION="${REGION:-ams3}"
    read -p "Endpoint [${REGION}.digitaloceanspaces.com]: " ENDPOINT
    ENDPOINT="${ENDPOINT:-${REGION}.digitaloceanspaces.com}"
    
    # Estrai nome remote da RCLONE_REMOTE (es: do:testmonbck -> do)
    REMOTE_NAME="${RCLONE_REMOTE%%:*}"
    
    log "Creo configurazione rclone remote '$REMOTE_NAME'..."
    
    # Crea configurazione rclone
    rclone config create "$REMOTE_NAME" s3 \
      provider='DigitalOcean' \
      env_auth='false' \
      access_key_id="$ACCESS_KEY" \
      secret_access_key="$SECRET_KEY" \
      region="$REGION" \
      endpoint="$ENDPOINT" \
      acl='private'
    
    if [[ $? -eq 0 ]]; then
      success "Configurazione rclone creata"
    else
      error "Configurazione rclone fallita"
      exit 1
    fi
  else
    error "Configurazione rclone necessaria per scaricare i backup"
    echo ""
    echo "Configura manualmente con: rclone config"
    exit 1
  fi
else
  success "Configurazione rclone trovata: $RCLONE_CONF"
fi

### SELEZIONE PATH BUCKET ###
title "🗂️  Path Bucket"

read -p "Path bucket [checkmk-backups/monitoring-compressed]: " RCLONE_PATH
RCLONE_PATH="${RCLONE_PATH:-checkmk-backups/monitoring-compressed}"

### VERIFICA CONNESSIONE STORAGE ###
title "📡 Verifica Connessione Storage Remoto"

log "Verifica connessione a $RCLONE_REMOTE/$RCLONE_PATH..."
if ! rclone lsd "$RCLONE_REMOTE/$RCLONE_PATH" --config="$RCLONE_CONF" --s3-no-check-bucket >/dev/null 2>&1; then
  error "Impossibile connettersi a $RCLONE_REMOTE/$RCLONE_PATH"
  echo ""
  echo "Verifica che:"
  echo "  1. La cartella $RCLONE_PATH esiste nel bucket"
  echo "  2. La configurazione rclone sia corretta: rclone config"
  exit 1
fi
success "Connessione OK"

### LISTA FILE DISPONIBILI ###
title "📦 File Disponibili"

log "Recupero lista file da $RCLONE_REMOTE/$RCLONE_PATH..."

# Lista tutti i file (incluse sottocartelle)
BACKUP_FILES=$(rclone lsf "$RCLONE_REMOTE/$RCLONE_PATH" --config="$RCLONE_CONF" --s3-no-check-bucket --recursive | sort -r)

if [[ -z "$BACKUP_FILES" ]]; then
  error "Nessun file trovato in $RCLONE_REMOTE/$RCLONE_PATH"
  exit 1
fi

echo ""
echo "File disponibili:"
echo ""
i=1
declare -A FILE_MAP
while IFS= read -r filename; do
  FILE_MAP[$i]="$filename"
  # Mostra dimensione se possibile
  FILE_SIZE=$(rclone size "$RCLONE_REMOTE/$RCLONE_PATH/$filename" --json --config="$RCLONE_CONF" --s3-no-check-bucket 2>/dev/null | grep -oP '(?<="bytes":)\d+' || echo "0")
  if [[ "$FILE_SIZE" -gt 0 ]]; then
    FILE_SIZE_HR=$(numfmt --to=iec-i --suffix=B "$FILE_SIZE" 2>/dev/null || echo "$FILE_SIZE bytes")
  else
    FILE_SIZE_HR="N/A"
  fi
  printf "%2d) %-50s [%s]\n" "$i" "$filename" "$FILE_SIZE_HR"
  ((i++))
done <<< "$BACKUP_FILES"

echo ""
read -p "Seleziona numero file (1-$((i-1))) o 'q' per uscire: " selection

if [[ "$selection" == "q" ]]; then
  error "Operazione annullata"
  exit 0
fi

if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -ge "$i" ]]; then
  error "Selezione non valida"
  exit 1
fi

SELECTED_FILE="${FILE_MAP[$selection]}"
success "Selezionato: $SELECTED_FILE"

### CONFERMA DOWNLOAD ###
title "⚠️  Conferma Download"

echo "Stai per scaricare:"
echo "  - File: $SELECTED_FILE"
echo "  - Da: $RCLONE_REMOTE/$RCLONE_PATH"
echo "  - A: $DOWNLOAD_DIR"
echo ""

if ! confirm "Vuoi procedere?" "y"; then
  error "Operazione annullata"
  exit 0
fi

### DOWNLOAD FILE ###
title "⬇️  Download File"

# Crea directory destinazione
mkdir -p "$DOWNLOAD_DIR"

log "Scarico $SELECTED_FILE..."
if rclone copy "$RCLONE_REMOTE/$RCLONE_PATH" "$DOWNLOAD_DIR/" \
  --config="$RCLONE_CONF" \
  --s3-no-check-bucket \
  --include "$SELECTED_FILE" \
  --progress; then
  
  success "Download completato"
  
  # Verifica file
  DOWNLOADED_FILE="$DOWNLOAD_DIR/$SELECTED_FILE"
  if [[ -f "$DOWNLOADED_FILE" ]]; then
    FILE_SIZE=$(du -h "$DOWNLOADED_FILE" | cut -f1)
    success "File salvato: $DOWNLOADED_FILE ($FILE_SIZE)"
    
    # Mostra permessi
    ls -lh "$DOWNLOADED_FILE"
  else
    error "File non trovato dopo il download"
    exit 1
  fi
else
  error "Download fallito"
  exit 1
fi

echo ""
success "✅ Operazione completata con successo!"
echo ""
echo "File scaricato in: $DOWNLOADED_FILE"

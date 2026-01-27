#!/bin/bash
set -euo pipefail

### SCRIPT COMPRESSIONE BACKUP NATIVI CHECKMK ###
# Prende backup nativi CheckMK e rimuove parti pesanti (RRD, inventory, agents)

BACKUP_DIR="/var/backups/checkmk"
SITE="${1:-monitoring}"
TMP_DIR="/opt/checkmk-backup/tmp"
LOCAL_BACKUP_DIR="/opt/checkmk-backup/compressed"
RCLONE_REMOTE="${RCLONE_REMOTE:-do:testmonbck}"
RCLONE_PATH="${RCLONE_PATH:-checkmk-backups/monitoring-compressed}"

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

### TROVA BACKUP PIÙ RECENTE ###
log "Cerco backup nativi CheckMK in $BACKUP_DIR..."

LATEST_BACKUP=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "Check_MK-*" | sort -r | head -1)

if [[ -z "$LATEST_BACKUP" ]]; then
  error "Nessun backup CheckMK trovato in $BACKUP_DIR"
  exit 1
fi

BACKUP_NAME=$(basename "$LATEST_BACKUP")
SITE_TAR="$LATEST_BACKUP/site-$SITE.tar.gz"

if [[ ! -f "$SITE_TAR" ]]; then
  error "File $SITE_TAR non trovato!"
  exit 1
fi

ORIGINAL_SIZE=$(du -h "$SITE_TAR" | cut -f1)
log "✅ Backup trovato: $BACKUP_NAME"
log "   Dimensione originale: $ORIGINAL_SIZE"

### ESTRAZIONE ###
mkdir -p "$TMP_DIR/extract"
cd "$TMP_DIR/extract"

log "Estraggo backup nativo..."
tar xzf "$SITE_TAR" 2>&1 | tail -5

EXTRACTED_SIZE=$(du -sh . | cut -f1)
log "✅ Estratto: $EXTRACTED_SIZE"

### ANALISI DIRECTORY PESANTI ###
log "Analizzo directory pesanti..."

echo ""
echo "TOP 10 directory per dimensione:"
du -sh var/check_mk/* 2>/dev/null | sort -rh | head -10 || true

### RIMOZIONE PARTI PESANTI ###
log "Rimuovo componenti pesanti..."

# Lista directory da rimuovere
REMOVE_DIRS=(
  "var/check_mk/rrd"                    # Dati storici grafici (300-400MB)
  "var/check_mk/inventory_archive"      # Archivio inventory (50-100MB)
  "var/check_mk/agents"                 # Agent bakery (20-50MB)
  "var/check_mk/wato/snapshots"         # Snapshot WATO storici
  "var/check_mk/wato/log"               # Log audit
  "var/log"                             # Log vari
  "tmp"                                 # File temporanei
)

REMOVED_SIZE=0
for dir in "${REMOVE_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    DIR_SIZE=$(du -sb "$dir" | cut -f1)
    REMOVED_SIZE=$((REMOVED_SIZE + DIR_SIZE))
    rm -rf "$dir"
    log "  ❌ Rimosso: $dir ($(numfmt --to=iec $DIR_SIZE))"
  fi
done

log "✅ Totale rimosso: $(numfmt --to=iec $REMOVED_SIZE)"

### RICOMPRESSIONE ###
COMPRESSED_NAME="checkmk-COMPRESSED-$SITE-$(date +%F_%H-%M-%S).tar.gz"
log "Ricomprimo backup ottimizzato..."

tar czf "$TMP_DIR/$COMPRESSED_NAME" . 2>&1 | tail -5

COMPRESSED_SIZE=$(du -h "$TMP_DIR/$COMPRESSED_NAME" | cut -f1)
COMPRESSED_BYTES=$(stat -c%s "$TMP_DIR/$COMPRESSED_NAME")

log "✅ Backup compresso creato: $COMPRESSED_SIZE"

# Calcola percentuale riduzione
ORIGINAL_BYTES=$(stat -c%s "$SITE_TAR")
REDUCTION=$(( 100 - (COMPRESSED_BYTES * 100 / ORIGINAL_BYTES) ))
log "📊 Riduzione dimensione: ${REDUCTION}%"

### CLEANUP ESTRAZIONE ###
cd "$TMP_DIR"
rm -rf "$TMP_DIR/extract"

### COPIA LOCALE ###
mkdir -p "$LOCAL_BACKUP_DIR"
log "Copio backup in $LOCAL_BACKUP_DIR..."
cp "$TMP_DIR/$COMPRESSED_NAME" "$LOCAL_BACKUP_DIR/"
LOCAL_PATH="$LOCAL_BACKUP_DIR/$COMPRESSED_NAME"
log "✅ Copia locale salvata"

### UPLOAD RCLONE ###
log "Upload su $RCLONE_REMOTE/$RCLONE_PATH/..."

if su - "$SITE" -c "rclone copy '$TMP_DIR/$COMPRESSED_NAME' '$RCLONE_REMOTE/$RCLONE_PATH/' --progress --s3-no-check-bucket --config=\$HOME/.config/rclone/rclone.conf"; then
  log "✅ Upload completato"
else
  error "Upload fallito!"
  exit 1
fi

### CLEANUP TMP ###
rm -f "$TMP_DIR/$COMPRESSED_NAME"

### RIEPILOGO ###
echo ""
log "=== RIEPILOGO ==="
log "Backup originale:    $ORIGINAL_SIZE"
log "Backup compresso:    $COMPRESSED_SIZE"
log "Riduzione:           ${REDUCTION}%"
log "Rimosso:             $(numfmt --to=iec $REMOVED_SIZE)"
log "Locale:              $LOCAL_PATH"
log "Cloud:               $RCLONE_REMOTE/$RCLONE_PATH/$COMPRESSED_NAME"
echo ""

exit 0

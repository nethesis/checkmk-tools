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

# Il backup nativo ha struttura: monitoring/var/, monitoring/etc/, ecc.
cd monitoring 2>/dev/null || { error "Struttura backup non riconosciuta"; exit 1; }

echo ""
echo "TOP 15 directory per dimensione:"
du -sh * 2>/dev/null | sort -rh | head -15 || true
echo ""
du -sh var/* 2>/dev/null | sort -rh | head -10 || true

### RIMOZIONE PARTI PESANTI ###
log "Rimuovo componenti pesanti..."

# Lista directory da rimuovere (path relativi da monitoring/)
REMOVE_DIRS=(
  "var/nagios"                          # Dati RRD Nagios (250MB)
  "checkmk-tools"                       # Repository git locale (150MB)
  "monitoring"                          # File binario non necessario (19MB)
  "var/check_mk/crashes"                # Crash reports (13MB)
  "var/check_mk/rest_api"               # Cache REST API (3.7MB)
  "var/check_mk/precompiled_checks"     # Check precompilati (3.6MB)
  "var/check_mk/logwatch"               # Log logwatch (1.9MB)
  "var/check_mk/wato/snapshots"         # Snapshot WATO storici
  "var/check_mk/wato/log"               # Log audit WATO
  "var/check_mk/inventory_archive"      # Archivio inventory
  "var/check_mk/background_jobs"        # Job background temporanei
  "var/log"                             # Log vari
  "var/tmp"                             # File temporanei
  "tmp"                                 # File temporanei
  ".bash_history"                       # Bash history
  ".cache"                              # Cache varie
  "debug_*.log"                         # Log debug
)

REMOVED_SIZE=0
for dir in "${REMOVE_DIRS[@]}"; do
  if [[ -d "$dir" ]] || [[ -f "$dir" ]]; then
    DIR_SIZE=$(du -sb "$dir" 2>/dev/null | cut -f1)
    REMOVED_SIZE=$((REMOVED_SIZE + DIR_SIZE))
    rm -rf "$dir"
    log "  ❌ Rimosso: $dir ($(numfmt --to=iec $DIR_SIZE))"
  fi
done

log "✅ Totale rimosso: $(numfmt --to=iec $REMOVED_SIZE)"

### RICOMPRESSIONE ###
COMPRESSED_NAME="site-$SITE.tar.gz"
COMPRESSED_TEMP="$TMP_DIR/$COMPRESSED_NAME.new"
log "Ricomprimo backup ottimizzato..."

# Torna alla root dell'estrazione (contiene monitoring/)
cd ..
tar czf "$COMPRESSED_TEMP" monitoring/ 2>&1 | tail -5

COMPRESSED_SIZE=$(du -h "$COMPRESSED_TEMP" | cut -f1)
COMPRESSED_BYTES=$(stat -c%s "$COMPRESSED_TEMP")

log "✅ Backup compresso creato: $COMPRESSED_SIZE"

# Calcola percentuale riduzione
ORIGINAL_BYTES=$(stat -c%s "$SITE_TAR")
REDUCTION=$(( 100 - (COMPRESSED_BYTES * 100 / ORIGINAL_BYTES) ))
log "📊 Riduzione dimensione: ${REDUCTION}%"

### CLEANUP ESTRAZIONE ###
cd "$TMP_DIR"
rm -rf "$TMP_DIR/extract"

### SOSTITUISCI FILE ORIGINALE ###
log "Sostituisco file originale con versione compressa..."
mv "$COMPRESSED_TEMP" "$SITE_TAR"
chown monitoring:monitoring "$SITE_TAR"
chmod 600 "$SITE_TAR"
LOCAL_PATH="$SITE_TAR"
log "✅ File sostituito: $SITE_TAR ($COMPRESSED_SIZE)"

### UPLOAD RCLONE ###
CLOUD_PATH="$RCLONE_PATH/$BACKUP_NAME"
log "Upload su $RCLONE_REMOTE/$CLOUD_PATH/..."

# Upload intera directory (mkbackup.info + site-monitoring.tar.gz)
if su - "$SITE" -c "rclone copy '$LATEST_BACKUP' '$RCLONE_REMOTE/$CLOUD_PATH/' --progress --s3-no-check-bucket --config=\$HOME/.config/rclone/rclone.conf"; then
  log "✅ Upload completato"
  log "   - mkbackup.info"
  log "   - site-$SITE.tar.gz ($COMPRESSED_SIZE)"
else
  error "Upload fallito!"
  exit 1
fi

### RIEPILOGO ###
echo ""
log "=== RIEPILOGO ==="
log "Backup originale:    $ORIGINAL_SIZE"
log "Backup compresso:    $COMPRESSED_SIZE"
log "Riduzione:           ${REDUCTION}%"
log "Rimosso:             $(numfmt --to=iec $REMOVED_SIZE)"
log "Directory locale:    $LATEST_BACKUP/"
log "  - mkbackup.info"
log "  - site-$SITE.tar.gz"
log "Cloud:               $RCLONE_REMOTE/$CLOUD_PATH/"
echo ""

exit 0

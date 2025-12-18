#!/usr/bin/env bash
set -euo pipefail

# Script interattivo per aggiornare la frequenza del ticket-monitor

TARGET_CMD="/opt/ydea-toolkit/rydea-ticket-monitor.sh"

echo "============================================================"
echo "  Configurazione frequenza ticket-monitor"
echo "============================================================"
echo

current_freq=""
if crontab -l 2>/dev/null | grep -q "$TARGET_CMD"; then
  current_freq=$(crontab -l 2>/dev/null | grep "$TARGET_CMD" | awk '{print $1}' | head -n 1)
fi

case "$current_freq" in
  "*/1") current_text="1 minuto" ;;
  "*/5") current_text="5 minuti" ;;
  "*/10") current_text="10 minuti" ;;
  "*/15") current_text="15 minuti" ;;
  "*/30") current_text="30 minuti" ;;
  "") current_text="non configurata" ;;
  *) current_text="$current_freq (personalizzato)" ;;
esac

echo "Frequenza attuale: $current_text"
echo
echo "Scegli nuova frequenza:"
echo "  1) Ogni 1 minuto   (*/1) - debug"
echo "  2) Ogni 5 minuti   (*/5)"
echo "  3) Ogni 10 minuti  (*/10)"
echo "  4) Ogni 15 minuti  (*/15)"
echo "  5) Ogni 30 minuti  (*/30)"
echo "  6) Personalizzato"
echo "  0) Esci"
echo

read -r -p "Scelta [1-6, 0]: " choice

new_freq=""
case "$choice" in
  1) new_freq="*/1" ;;
  2) new_freq="*/5" ;;
  3) new_freq="*/10" ;;
  4) new_freq="*/15" ;;
  5) new_freq="*/30" ;;
  6)
    echo
    read -r -p "Inserisci frequenza (es. */5 oppure 0,15,30,45): " new_freq
    ;;
  0)
    echo "Annullato."
    exit 0
    ;;
  *)
    echo "ERRORE: scelta non valida" >&2
    exit 1
    ;;
esac

echo
echo "Cambio frequenza: ${current_freq:-<none>} -> $new_freq"
echo
read -r -p "Confermi? [s/N]: " confirm
if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
  echo "Annullato."
  exit 0
fi

backup_file="/tmp/crontab.backup.$(date +%Y%m%d_%H%M%S)"
crontab -l 2>/dev/null > "$backup_file" || true
echo "Backup crontab: $backup_file"

current_tab=$(mktemp)
new_tab=$(mktemp)
trap 'rm -f "$current_tab" "$new_tab"' EXIT

crontab -l 2>/dev/null > "$current_tab" || true

grep -v "$TARGET_CMD" "$current_tab" > "$new_tab" || true
echo "$new_freq * * * * $TARGET_CMD" >> "$new_tab"
crontab "$new_tab"

echo
echo "OK: Crontab aggiornato"
echo
echo "Configurazione attuale (filtrata):"
crontab -l 2>/dev/null | grep -E "ydea-ticket-monitor|ydea-health-monitor" || true

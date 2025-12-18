#!/usr/bin/env bash
set -euo pipefail

TRACKING_FILE="/var/log/ydea-tickets-tracking.json"
YDEA_TOOLKIT="/opt/checkmk-tools/Ydea-Toolkit/full/ydea-toolkit.sh"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing command: $1" >&2
    exit 1
  }
}

require_cmd jq

if [[ ! -f "$TRACKING_FILE" ]]; then
  echo "ERROR: tracking file not found: $TRACKING_FILE" >&2
  exit 1
fi

echo "=== DEBUG MONITOR ==="
echo

echo "1. Lettura PREVIOUS (prima di update-tracking):"
jq -r '.tickets[] | select(.resolved_at == null) | "\(.ticket_id)|\(.stato)|\(.descrizione_ticket // \"\")|\(.priorita // \"Normale\")|\(.assegnatoA // \"Non assegnato\")"' "$TRACKING_FILE"

echo
echo "2. Parsing con while loop (simula monitor):"
while IFS='|' read -r tid stato desc prio assegnato; do
  echo "tid=$tid"
  echo "stato=$stato"
  echo "desc=$desc"
  echo "prio=$prio"
  echo "assegnato=$assegnato"
done < <(
  jq -r '.tickets[] | select(.resolved_at == null) | "\(.ticket_id)|\(.stato)|\(.descrizione_ticket // \"\")|\(.priorita // \"Normale\")|\(.assegnatoA // \"Non assegnato\")"' "$TRACKING_FILE"
)

echo
echo "3. Eseguo update-tracking:"
"$YDEA_TOOLKIT" update-tracking

echo
echo "4. Lettura CURRENT (dopo update-tracking):"
jq -r '.tickets[] | "\(.ticket_id)|\(.stato)|\(.host)|\(.service)|\(.codice)|\(.descrizione_ticket // \"\")|\(.priorita // \"Normale\")|\(.assegnatoA // \"Non assegnato\")"' "$TRACKING_FILE"

echo
echo "5. Parsing con while loop COMPLETO (8 campi):"
while IFS='|' read -r tid stato host service codice desc prio assegnato _extra; do
  echo "tid=$tid"
  echo "stato=$stato"
  echo "host=$host"
  echo "service=$service"
  echo "codice=$codice"
  echo "desc=$desc"
  echo "prio=$prio"
  echo "assegnato=$assegnato"
  echo "_extra=$_extra"
done < <(
  jq -r '.tickets[] | "\(.ticket_id)|\(.stato)|\(.host)|\(.service)|\(.codice)|\(.descrizione_ticket // \"\")|\(.priorita // \"Normale\")|\(.assegnatoA // \"Non assegnato\")"' "$TRACKING_FILE"
)

#!/usr/bin/env bash

set -euo pipefail

# list-tipo-values.sh - List all values from 'tipo' field

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ydea-toolkit.sh"

PAGES="${1:-30}"

echo "Collecting 'tipo' values from $PAGES pages..."
echo ""

ensure_token
TOKEN="$(load_token)"

declare -A TIPO_MAP

for PAGE in $(seq 1 "$PAGES"); do
  echo -n "   Page $PAGE/$PAGES... "

  RESPONSE=$(curl -s \
    -H "Accept: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    "${YDEA_BASE_URL}/tickets?limit=100&page=${PAGE}")

  if ! echo "$RESPONSE" | jq -e '.objs' >/dev/null 2>&1; then
    echo "ERROR"
    break
  fi

  COUNT=$(echo "$RESPONSE" | jq -r '.objs | length')
  if [[ "$COUNT" -eq 0 ]]; then
    echo "Done"
    break
  fi

  echo "$COUNT tickets"

  # Extract all 'tipo' values
  while IFS= read -r tipo; do
    [[ -z "$tipo" || "$tipo" == "null" ]] && continue
    TIPO_MAP["$tipo"]=1
  done < <(echo "$RESPONSE" | jq -r '.objs[].tipo // empty')
done

echo ""
echo "=== ALL 'tipo' FIELD VALUES (${#TIPO_MAP[@]} unique) ==="
echo ""
printf '%s\n' "${!TIPO_MAP[@]}" | sort | while IFS= read -r tipo; do
  echo "  • $tipo"
done

echo ""
echo "=== MAPPING WITH REQUIRED SUBCATEGORIES ==="
echo ""

declare -a REQUIRED=(
  "Centrale telefonica NethVoice"
  "Firewall UTM NethSecurity"
  "Collaboration Suite NethService"
  "Computer client"
  "Server"
  "Apparati di rete - Networking"
  "Hypervisor"
  "Consulenza tecnica specialistica"
)

for required in "${REQUIRED[@]}"; do
  found=""
  keyword=$(echo "$required" | sed 's/ .*//' | tr '[:upper:]' '[:lower:]')

  while IFS= read -r tipo; do
    if echo "$tipo" | tr '[:upper:]' '[:lower:]' | grep -q "$keyword"; then
      found="$tipo"
      break
    fi
  done < <(printf '%s\n' "${!TIPO_MAP[@]}")

  if [[ -n "$found" ]]; then
    echo "  ✓ $required"
    echo "     → '$found'"
  else
    echo "  ✗ $required"
    echo "     → NOT FOUND"
  fi
  echo ""
done

exit 0
echo "Ô£à Analisi completata!"

#!/bin/bash
/usr/bin/env bash
# list-tipo-values.sh - Lista tutti i valori del campo 'tipo'set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"source "$SCRIPT_DIR/ydea-toolkit.sh"
PAGES="${1:-30}"
echo "­ƒöì Raccolta valori del campo 'tipo' da $PAGES pagine..."
echo ""ensure_token
TOKEN="$(load_token)"declare -A TIPO_MAPfor PAGE in $(seq 1 $PAGES); do  
echo -n "   Pagina $PAGE/$PAGES... "    
RESPONSE=$(curl -s \    -H "Accept: application/json" \    -H "Authorization: Bearer ${TOKEN}" \    "${YDEA_BASE_URL}/tickets?limit=100&page=${PAGE}")  if ! 
echo "$RESPONSE" | jq -e '.objs' >/dev/null 2>&1; then
    echo "ÔØî Errore"    break  fi  
COUNT=$(
echo "$RESPONSE" | jq -r '.objs | length')  if [[ "$COUNT" -eq 0 ]]; then
    echo "Fine"    break  fi
echo "$COUNT ticket"    
# Estrai tutti i valori 'tipo'  while 
IFS= read -r tipo; do    [[ -z "$tipo" || "$tipo" == "null" ]] && continue    TIPO_MAP["$tipo"]=1  done < <(
echo "$RESPONSE" | jq -r '.objs[].tipo // empty')done
echo ""
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "TUTTI I VALORI DEL CAMPO 'tipo' ($(printf '%s\n' "${!TIPO_MAP[@]}" | wc -l) valori unici)"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo ""printf '%s\n' "${!TIPO_MAP[@]}" | sort | while 
IFS= read -r tipo; do  
echo "  ÔÇó $tipo"
done
echo ""
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "MAPPING CON LE SOTTOCATEGORIE RICHIESTE"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo ""
echo "Sottocategorie richieste ÔåÆ Valori 'tipo' trovati:"
echo ""
# Array di sottocategorie richiestedeclare -a 
REQUIRED=(  "Centrale telefonica NethVoice"  "Firewall UTM NethSecurity"  "Collaboration Suite NethService"  "Computer client"  "Server"  "Apparati di rete - Networking"  "Hypervisor"  "Consulenza tecnica specialistica")
# Cerca corrispondenzefor required in "${REQUIRED[@]}"; do  found=""  
# Cerca tra i tipi trovati  while 
IFS= read -r tipo; do    
# Match case-insensitive con parole chiave    keyword=$(
echo "$required" | sed 's/ .*//' | tr '[:upper:]' '[:lower:]')    if 
echo "$tipo" | tr '[:upper:]' '[:lower:]' | grep -q "$keyword"; then
    found="$tipo"      break    fi  done < <(printf '%s\n' "${!TIPO_MAP[@]}")    if [[ -n "$found" ]]; then
    echo "  Ô£à $required"    
echo "     ÔåÆ '$found'"
else    
echo "  ÔØî $required"    
echo "     ÔåÆ NON TROVATO"  fi
echo ""done
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "RICERCA PRIORITA' (priorita_id)"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo ""
# Raccogli anche priorit├ádeclare -A PRIO_MAPfor PAGE in $(seq 1 5); do  
RESPONSE=$(curl -s \    -H "Accept: application/json" \    -H "Authorization: Bearer ${TOKEN}" \    "${YDEA_BASE_URL}/tickets?limit=100&page=${PAGE}")  while 
IFS='|' read -r pid pname; do    [[ -z "$pid" || "$pid" == "null" ]] && continue    PRIO_MAP["$pid"]="$pname"  done < <(
echo "$RESPONSE" | jq -r '.objs[] | "\(.priorita_id // "")|\(.priorita // "")"')done
echo "Mapping Priorit├á (ID ÔåÆ Nome):"for pid in $(printf '%s\n' "${!PRIO_MAP[@]}" | sort -n); do  
echo "  $pid ÔåÆ ${PRIO_MAP[$pid]}"done
echo ""
echo "Ô£à Analisi completata!"

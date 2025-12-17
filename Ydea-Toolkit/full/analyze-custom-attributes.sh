
#!/bin/bash
/usr/bin/env bash
# analyze-custom-attributes.sh - Analizza i customAttributes di molti ticketset -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"source "$SCRIPT_DIR/ydea-toolkit.sh"
PAGES="${1:-20}"  
# Numero di pagine da analizzare (default: 20 = 2000 ticket)
echo "­ƒöì Analisi customAttributes su $PAGES pagine di ticket..."
echo ""ensure_token
TOKEN="$(load_token)"
# File temporaneo per raccogliere tutti i customAttributes
TEMP_FILE="/tmp/all-custom-attributes.json"
echo "[]" > "$TEMP_FILE"
echo "­ƒôí Raccolta dati in corso..."for PAGE in $(seq 1 $PAGES); do  
echo -n "   Pagina $PAGE/$PAGES... "    
RESPONSE=$(curl -s -w '\n%{http_code}' \    -H "Accept: application/json" \    -H "Authorization: Bearer ${TOKEN}" \    "${YDEA_BASE_URL}/tickets?limit=100&page=${PAGE}")  
HTTP_BODY="$(
echo "$RESPONSE" | sed '$d')"  
HTTP_CODE="$(
echo "$RESPONSE" | tail -n1)"  if [[ "$HTTP_CODE" != "200" ]]; then    
echo "ÔØî Errore HTTP $HTTP_CODE"    break  fi  
COUNT=$(
echo "$HTTP_BODY" | jq -r '.objs | length')  if [[ "$COUNT" -eq 0 ]]; then    
echo "Nessun ticket, fine"    break  fi    
echo "$COUNT ticket"    
# Estrai customAttributes con ID ticket  
echo "$HTTP_BODY" | jq '[.objs[] | select(.customAttributes != null) | {id, codice, customAttributes}]' >> "$TEMP_FILE.part"done
echo ""
echo "­ƒôè Elaborazione dati..."
# Combina tutti i risultatijq -s 'add' "$TEMP_FILE.part" 2>/dev/null > "$TEMP_FILE" || 
echo "[]" > "$TEMP_FILE"rm -f "$TEMP_FILE.part"
TOTAL_TICKETS=$(jq 'length' "$TEMP_FILE")
echo "   Totale ticket con customAttributes: $TOTAL_TICKETS"
echo ""
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "TUTTI I NOMI DI CUSTOM ATTRIBUTES TROVATI"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo ""
# Estrai tutti i nomi di custom attributes unicijq -r '[.[].customAttributes | keys[]] | unique | sort[]' "$TEMP_FILE"
echo ""
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "CUSTOM ATTRIBUTES CONTENENTI 'CATEGORIA', 'SLA' O 'PREMIUM'"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo ""
# Cerca attributi con parole chiave
MATCHING_ATTRS=$(jq -r '[.[].customAttributes | keys[]] | unique | map(select(test("categoria|sla|premium|mon|macro"; "i"))) | sort[]' "$TEMP_FILE")if [[ -n "$MATCHING_ATTRS" && "$MATCHING_ATTRS" != "null" ]]; then  
echo "$MATCHING_ATTRS"  
echo ""    
# Per ogni attributo trovato, mostra alcuni esempi  while 
IFS= read -r ATTR; do    [[ -z "$ATTR" ]] && continue    
echo "ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ"    
echo "Esempi per attributo: '$ATTR'"    
echo "ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ"        jq --arg attr "$ATTR" -r '      [.[] | select(.customAttributes[$attr] != null) |        {id, codice, valore: .customAttributes[$attr]}] |       unique_by(.valore) |       sort_by(.valore) |       .[] |       "  [\(.id)] \(.codice) ÔåÆ \(.valore)"    ' "$TEMP_FILE" | head -20    
echo ""  done <<< "$MATCHING_ATTRS"else  
echo "ÔÜá´©Å  Nessun custom attribute trovato con queste parole chiave"  
echo ""fi
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "VALORI DEL CAMPO 'tipo' (Potenziali Sottocategorie)"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo ""
# Analizza anche il campo tipo
TIPO_FILE="/tmp/all-tipo-values.json"
echo "[]" > "$TIPO_FILE"for PAGE in $(seq 1 $PAGES); do  curl -s \    -H "Accept: application/json" \    -H "Authorization: Bearer ${TOKEN}" \    "${YDEA_BASE_URL}/tickets?limit=100&page=${PAGE}" | \    jq '[.objs[] | select(.tipo != null) | {tipo}]' >> "$TIPO_FILE.part" 2>/dev/null || truedonejq -s 'add | map(.tipo) | unique | sort[]' "$TIPO_FILE.part" 2>/dev/null > "$TIPO_FILE" || 
echo "[]" > "$TIPO_FILE"rm -f "$TIPO_FILE.part"
echo "Valori unici del campo 'tipo':"jq -r '.[]' "$TIPO_FILE" | sed 's/^/  - /'
echo ""
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "RICERCA SPECIFICA: Ticket con 'Premium' o 'Mon' nei customAttributes"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo ""
PREMIUM_TICKETS=$(jq '[.[] | select(.customAttributes | tostring | test("Premium|Mon|premium|mon"))] | length' "$TEMP_FILE")
echo "Ticket trovati: $PREMIUM_TICKETS"if [[ "$PREMIUM_TICKETS" -gt 0 ]]; then  
echo ""  
echo "Primi 10 ticket con 'Premium' o 'Mon':"  jq -r '[.[] | select(.customAttributes | tostring | test("Premium|Mon|premium|mon"))] |     .[0:10][] |     "  [\(.id)] \(.codice) ÔåÆ " + (.customAttributes | tojson)' "$TEMP_FILE"fi
echo ""
echo "Ô£à Analisi completata!"
echo ""
echo "­ƒÆ¥ File salvati:"
echo "   - $TEMP_FILE (tutti i customAttributes)"
echo "   - $TIPO_FILE (tutti i valori 'tipo')"
echo ""
echo "­ƒÆí Usa questi comandi per ulteriori analisi:"
echo "   cat $TEMP_FILE | jq '.[] | select(.customAttributes | has(\"NOME_CAMPO\"))'"
echo "   cat $TEMP_FILE | jq '[.[].customAttributes | keys[]] | unique'"

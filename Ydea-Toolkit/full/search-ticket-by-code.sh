#!/usr/bin/env bash

set -euo pipefail

# search-ticket-by-code.sh - Cerca un ticket per codice (es: TK25/003209)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ydea-toolkit.sh"

TICKET_CODE="${1:-}"

if [[ -z "$TICKET_CODE" ]]; then
  echo "Usage: $0 <ticket_code>"
  echo ""
  echo "Example:"
  echo "  $0 TK25/003209"
  exit 1
fi

echo "Searching ticket: $TICKET_CODE"
echo ""

ensure_token
TOKEN="$(load_token)"

for LIMIT in 100 200 500 1000; do
  echo "Trying with limit=$LIMIT..."

  RESPONSE=$(curl -s -w '\n%{http_code}' \
    -H "Accept: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    "${YDEA_BASE_URL}/tickets?limit=${LIMIT}")

  HTTP_BODY="$(echo "$RESPONSE" | sed '$d')"
  HTTP_CODE="$(echo "$RESPONSE" | tail -n1)"

  if [[ "$HTTP_CODE" != "200" ]]; then
    echo "HTTP error $HTTP_CODE"
    continue
  fi

  TICKET_DATA=$(echo "$HTTP_BODY" | jq --arg code "$TICKET_CODE" '.objs[] | select(.codice == $code)' 2>/dev/null || echo "")

  if [[ -n "$TICKET_DATA" && "$TICKET_DATA" != "null" ]]; then
    echo "✓ Ticket found with limit=$LIMIT!"
    echo ""

    TICKET_ID=$(echo "$TICKET_DATA" | jq -r '.id')
    TICKET_TITLE=$(echo "$TICKET_DATA" | jq -r '.titolo // "N/A"')
    TICKET_PRIORITY=$(echo "$TICKET_DATA" | jq -r '.priorita // "N/A"')
    TICKET_CATEGORY=$(echo "$TICKET_DATA" | jq -r '.categoria // "N/A"')
    TICKET_SLA=$(echo "$TICKET_DATA" | jq -r '.sla // "N/A"')
    TICKET_STATE=$(echo "$TICKET_DATA" | jq -r '.stato // "N/A"')

    echo "========================================="
    echo "TICKET $TICKET_CODE (ID: $TICKET_ID)"
    echo "========================================="
    echo ""
    echo "Title: $TICKET_TITLE"
    echo "Priority: $TICKET_PRIORITY"
    echo "Category: $TICKET_CATEGORY"
    echo "SLA: $TICKET_SLA"
    echo "State: $TICKET_STATE"
    echo ""
    echo "Full JSON:"
    echo "$TICKET_DATA" | jq '.'
    echo ""

    exit 0
  fi
done

echo "ERROR: Ticket $TICKET_CODE not found" >&2
exit 1

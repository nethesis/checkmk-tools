#!/usr/bin/env bash

set -euo pipefail

# Test creazione ticket con contratto associato
# 
# PREREQUISITI:
# 1. Devi aver creato un contratto in Ydea UI per l'anagrafica 2339268
# 2. Il contratto deve avere SLA "Premium_Mon" configurato
# 3. Devi passare l'ID del contratto come parametro
#
# USO:
#   ./test-ticket-with-contract.sh <CONTRATTO_ID>
#
# ESEMPIO:
#   ./test-ticket-with-contract.sh 168912

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT="${SCRIPT_DIR}/rydea-toolkit.sh"

if [[ ! -f "$TOOLKIT" ]]; then
  echo -e "${RED}ERROR: $TOOLKIT not found${NC}" >&2
  exit 1
fi

if [[ -z "${1:-}" ]]; then
  echo -e "${RED}ERROR: Must specify contract ID${NC}" >&2
  echo ""
  echo "Usage: $0 <CONTRACT_ID>"
  echo ""
  echo "To get contract ID:"
  echo "  ./rydea-toolkit.sh api GET '/contratti?page=1' | jq '.objs[] | {id, nome, azienda_id}'"
  exit 1
fi

CONTRATTO_ID="$1"
ANAGRAFICA_ID=2339268

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Test: Ticket con Contratto Associato${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}Step 1: Verifying contract ${CONTRATTO_ID}...${NC}"
CONTRATTO_JSON=$("$TOOLKIT" api GET "/contratto/${CONTRATTO_ID}" 2>/dev/null || echo "")

if [[ -z "$CONTRATTO_JSON" ]] || echo "$CONTRATTO_JSON" | grep -q "404"; then
  echo -e "${RED}ERROR: Contract ${CONTRATTO_ID} not found${NC}" >&2
  exit 1
fi

CONTRATTO_NOME=$(echo "$CONTRATTO_JSON" | jq -r '.nome // "N/A"')
CONTRATTO_AZIENDA_ID=$(echo "$CONTRATTO_JSON" | jq -r '.azienda_id // 0')

echo -e "${GREEN}✓ Contract found:${NC}"
echo "   - ID: ${CONTRATTO_ID}"
echo "   - Name: ${CONTRATTO_NOME}"
echo "   - Azienda ID: ${CONTRATTO_AZIENDA_ID}"
echo ""

if [[ "$CONTRATTO_AZIENDA_ID" != "$ANAGRAFICA_ID" ]]; then
  echo -e "${RED}ERROR: Contract not for azienda ${ANAGRAFICA_ID}${NC}" >&2
  exit 1
fi

echo -e "${GREEN}✓ Contract belongs to correct azienda${NC}"
echo ""

echo -e "${YELLOW}Step 2: Creating test ticket...${NC}"

TICKET_PAYLOAD=$(cat <<EOF
{
  "ticket": {
    "titolo": "TEST Ticket with Contract - $(date '+%Y-%m-%d %H:%M:%S')",
    "descrizione": "Ticket for testing SLA automation via contract.\n\nDetails:\n- Contract ID: ${CONTRATTO_ID}\n- Contract: ${CONTRATTO_NOME}\n- Azienda ID: ${ANAGRAFICA_ID}\n- Date: $(date '+%Y-%m-%d %H:%M:%S')",
    "anagrafica_id": ${ANAGRAFICA_ID},
    "contrattoId": ${CONTRATTO_ID},
    "priorita_id": 30,
    "fonte_id": 91,
    "tipo_id": 32,
    "categoria_id": 100
  }
}
EOF
)

RESPONSE=$("$TOOLKIT" api POST "/ticket" - <<<"$TICKET_PAYLOAD" 2>&1 || true)

if echo "$RESPONSE" | grep -q "fallita\|error\|404"; then
  echo -e "${RED}ERROR: API call failed${NC}" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

TICKET_ID=$(echo "$RESPONSE" | jq -r '.ticket.id // empty' 2>/dev/null || true)

if [[ -z "$TICKET_ID" ]]; then
  echo -e "${RED}ERROR: Could not extract ticket ID${NC}" >&2
  exit 1
fi

echo -e "${GREEN}✓ Ticket created: #${TICKET_ID}${NC}"
echo ""

echo -e "${YELLOW}Step 3: Verifying ticket details...${NC}"
sleep 2

TICKET_DETAILS=$("$TOOLKIT" api GET "/ticket/${TICKET_ID}" 2>/dev/null || true)

TICKET_CONTRATTO_ID=$(echo "$TICKET_DETAILS" | jq -r '.ticket.contrattoId // 0' 2>/dev/null || true)

echo -e "${BLUE}Ticket Details:${NC}"
echo "   - ID: ${TICKET_ID}"
echo "   - Contract ID: ${TICKET_CONTRATTO_ID}"
echo ""

if [[ "$TICKET_CONTRATTO_ID" = "$CONTRATTO_ID" ]] && [[ "$TICKET_CONTRATTO_ID" != "0" ]] && [[ "$TICKET_CONTRATTO_ID" != "null" ]]; then
  echo -e "${GREEN}✓ SUCCESS: Contract associated correctly!${NC}"
  echo ""
  echo -e "${YELLOW}MANUAL VERIFICATION:${NC}"
  echo "1. Go to: https://my.ydea.cloud"
  echo "2. Open ticket: #${TICKET_ID}"
  echo "3. Check that SLA field shows: 'Premium_Mon'"
else
  echo -e "${RED}⚠ WARNING: Contract not associated${NC}" >&2
  echo "   Expected: ${CONTRATTO_ID}"
  echo "   Got: ${TICKET_CONTRATTO_ID}"
fi

echo ""
echo "Ticket ID: ${TICKET_ID}"
echo "Contract ID: ${CONTRATTO_ID}"

#!/bin/bash
################################################################################
# Script per testare la creazione di un ticket con contratto associato
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
#
# Lo script:
# - Crea un ticket di test con il contrattoId specificato
# - Verifica che il ticket sia stato creato correttamente
# - Controlla se il contratto è stato associato
# - Mostra l'ID del ticket per verifica manuale in Ydea UI
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT="${SCRIPT_DIR}/rydea-toolkit.sh"

# Verifica parametri
if [ -z "$1" ]; then
    echo -e "${RED}❌ Errore: Devi specificare l'ID del contratto${NC}"
    echo ""
    echo "Uso: $0 <CONTRATTO_ID>"
    echo ""
    echo "Come ottenere l'ID del contratto:"
    echo "1. Accedi a https://my.ydea.cloud"
    echo "2. Vai all'anagrafica 'AZIENDA MONITORATA test' (ID: 2339268)"
    echo "3. Crea un nuovo contratto con SLA 'Premium_Mon'"
    echo "4. Dopo la creazione, esegui:"
    echo "   ./rydea-toolkit.sh api GET '/contratti?page=1' | jq '.objs[] | select(.azienda_id == 2339268)'"
    echo "5. Annota il campo 'id' del contratto"
    exit 1
fi

CONTRATTO_ID="$1"
ANAGRAFICA_ID=2339268

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Test Creazione Ticket con Contratto Associato${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Verifica che il contratto esista
echo -e "${YELLOW}📋 Step 1: Verifica esistenza contratto ID ${CONTRATTO_ID}...${NC}"
CONTRATTO_JSON=$("${TOOLKIT}" api GET "/contratto/${CONTRATTO_ID}" 2>/dev/null || echo "")

if [ -z "$CONTRATTO_JSON" ] || echo "$CONTRATTO_JSON" | grep -q "404"; then
    echo -e "${RED}❌ Errore: Contratto ${CONTRATTO_ID} non trovato!${NC}"
    echo ""
    echo "Verifica l'ID del contratto con:"
    echo "  ./rydea-toolkit.sh api GET '/contratti' | jq '.objs[] | {id, nome, azienda_id}'"
    exit 1
fi

CONTRATTO_NOME=$(echo "$CONTRATTO_JSON" | jq -r '.nome // "N/A"')
CONTRATTO_AZIENDA_ID=$(echo "$CONTRATTO_JSON" | jq -r '.azienda_id // 0')

echo -e "${GREEN}✅ Contratto trovato:${NC}"
echo "   - ID: ${CONTRATTO_ID}"
echo "   - Nome: ${CONTRATTO_NOME}"
echo "   - Azienda ID: ${CONTRATTO_AZIENDA_ID}"
echo ""

# Step 2: Verifica che il contratto appartenga all'anagrafica corretta
if [ "$CONTRATTO_AZIENDA_ID" != "$ANAGRAFICA_ID" ]; then
    echo -e "${RED}❌ Errore: Il contratto ${CONTRATTO_ID} non appartiene all'anagrafica ${ANAGRAFICA_ID}!${NC}"
    echo "   Appartiene invece all'anagrafica ${CONTRATTO_AZIENDA_ID}"
    exit 1
fi

echo -e "${GREEN}✅ Contratto associato all'anagrafica corretta${NC}"
echo ""

# Step 3: Crea il ticket di test con il contratto
echo -e "${YELLOW}🎫 Step 2: Creazione ticket di test con contratto...${NC}"

TICKET_PAYLOAD=$(cat <<EOF
{
  "ticket": {
    "titolo": "TEST Ticket con Contratto - $(date '+%Y-%m-%d %H:%M:%S')",
    "descrizione": "Ticket di test per verificare l'associazione automatica dello SLA tramite contratto.\n\nDettagli test:\n- Contratto ID: ${CONTRATTO_ID}\n- Contratto: ${CONTRATTO_NOME}\n- Anagrafica ID: ${ANAGRAFICA_ID}\n- Data test: $(date '+%Y-%m-%d %H:%M:%S')\n\nQuesto ticket dovrebbe avere automaticamente lo SLA 'Premium_Mon' applicato.",
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

echo "Payload JSON:"
echo "$TICKET_PAYLOAD" | jq '.'
echo ""

RESPONSE=$("${TOOLKIT}" api POST "/ticket" - <<< "$TICKET_PAYLOAD" 2>&1)

if echo "$RESPONSE" | grep -q "API call fallita"; then
    echo -e "${RED}❌ Errore durante la creazione del ticket${NC}"
    echo "$RESPONSE"
    exit 1
fi

# Estrai l'ID del ticket creato
TICKET_ID=$(echo "$RESPONSE" | jq -r '.ticket.id // empty')

if [ -z "$TICKET_ID" ]; then
    echo -e "${RED}❌ Errore: Impossibile estrarre l'ID del ticket dalla risposta${NC}"
    echo "Risposta API:"
    echo "$RESPONSE" | jq '.'
    exit 1
fi

echo -e "${GREEN}✅ Ticket creato con successo!${NC}"
echo "   - Ticket ID: ${TICKET_ID}"
echo ""

# Step 4: Verifica il ticket creato
echo -e "${YELLOW}🔍 Step 3: Verifica dettagli ticket creato...${NC}"
sleep 2  # Pausa per permettere a Ydea di processare

TICKET_DETAILS=$("${TOOLKIT}" api GET "/ticket/${TICKET_ID}")

TICKET_TITOLO=$(echo "$TICKET_DETAILS" | jq -r '.ticket.titolo')
TICKET_CONTRATTO_ID=$(echo "$TICKET_DETAILS" | jq -r '.ticket.contrattoId')
TICKET_CONTRATTO_CODICE=$(echo "$TICKET_DETAILS" | jq -r '.ticket.contrattoCodice')
TICKET_ANAGRAFICA=$(echo "$TICKET_DETAILS" | jq -r '.ticket.anagrafica')

echo -e "${BLUE}📋 Dettagli Ticket:${NC}"
echo "   - ID: ${TICKET_ID}"
echo "   - Titolo: ${TICKET_TITOLO}"
echo "   - Anagrafica: ${TICKET_ANAGRAFICA}"
echo "   - Contratto ID: ${TICKET_CONTRATTO_ID}"
echo "   - Contratto Codice: ${TICKET_CONTRATTO_CODICE}"
echo ""

# Step 5: Verifica finale
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  RISULTATO TEST${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$TICKET_CONTRATTO_ID" = "$CONTRATTO_ID" ] && [ "$TICKET_CONTRATTO_ID" != "0" ] && [ "$TICKET_CONTRATTO_ID" != "null" ]; then
    echo -e "${GREEN}✅ SUCCESSO: Il contratto è stato associato correttamente al ticket!${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  VERIFICA MANUALE NECESSARIA:${NC}"
    echo ""
    echo "1. Accedi a: https://my.ydea.cloud"
    echo "2. Apri il ticket: #${TICKET_ID}"
    echo "3. Verifica che il campo SLA mostri: 'Premium_Mon'"
    echo "4. Verifica che il contratto sia: '${TICKET_CONTRATTO_CODICE}'"
    echo ""
    echo "Se il campo SLA è correttamente impostato, l'automazione funziona! 🎉"
else
    echo -e "${RED}❌ ATTENZIONE: Il contratto non sembra essere stato associato correttamente${NC}"
    echo ""
    echo "Dettagli:"
    echo "   - Contratto richiesto: ${CONTRATTO_ID}"
    echo "   - Contratto nel ticket: ${TICKET_CONTRATTO_ID}"
    echo ""
    echo "Possibili cause:"
    echo "   1. Il contratto non è attivo"
    echo "   2. Il contratto non ha date valide"
    echo "   3. API v2 non supporta l'associazione contratto in creazione"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Output finale per uso in script
echo "# Informazioni per script di automazione:"
echo "TICKET_ID=${TICKET_ID}"
echo "CONTRATTO_ID=${CONTRATTO_ID}"
echo "CONTRATTO_ASSOCIATO=$([[ "$TICKET_CONTRATTO_ID" = "$CONTRATTO_ID" ]] && echo "true" || echo "false")"

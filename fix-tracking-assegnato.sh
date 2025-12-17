#!/bin/bash
# Script temporaneo per forzare update del tracking con il campo assegnatoA
echo "­ƒöä Forzo aggiornamento tracking con nuovo campo assegnatoA..."
# Rimuovi il tracking attualerm -f /var/log/ydea-tickets-tracking.json
# Forza re-tracking del ticket esistente
# Sintassi: track <ticket_id> <codice> <host> <service> <description>/opt/checkmk-tools/Ydea-Toolkit/full/ydea-toolkit.sh track \  1528466 \  "TK25/003619" \  test-host \  test-service \  "Test monitoraggio modifiche"
echo ""
echo "Ô£à Tracking ricreato. Verifica con:"
echo "cat /var/log/ydea-tickets-tracking.json | jq '.tickets[0] | {ticket_id, assegnatoA}'"

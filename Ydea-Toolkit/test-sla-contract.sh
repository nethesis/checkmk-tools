#!/bin/bash
cd /opt/checkmk-tools/Ydea-Toolkit/full
source ydea-toolkit.sh

# Test A: Con serviceLevelAgreement esplicito
echo "=== TEST A: Con SLA esplicito ==="
ydea_api POST "/ticket" '{
  "titolo": "TEST A - SLA esplicito v2",
  "testo": "Test con serviceLevelAgreement=147",
  "priorita": 30,
  "anagrafica_id": 2339268,
  "contrattoId": 171734,
  "serviceLevelAgreement": 147,
  "fonte": "Partner portal",
  "tipo": "Server"
}'

echo ""
echo "=== TEST B: Senza SLA (solo contratto) ==="
ydea_api POST "/ticket" '{
  "titolo": "TEST B - Solo contratto v2",
  "testo": "Test senza serviceLevelAgreement (solo contrattoId)",
  "priorita": 30,
  "anagrafica_id": 2339268,
  "contrattoId": 171734,
  "fonte": "Partner portal",
  "tipo": "Server"
}'

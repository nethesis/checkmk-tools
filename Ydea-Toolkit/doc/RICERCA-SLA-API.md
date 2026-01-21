# Ricerca SLA tramite API Ydea v2

## Obiettivo
Impostare automaticamente il campo "Nome SLA" durante la creazione di ticket via API.

## Configurazione Corrente
- **SLA desiderato**: Premium_Mon
- **ID ipotizzato**: 147 (da `premium-mon-config.json`)
- **Anagrafica test**: 2339268
- **Ticket test**: 1533729
- **API Base URL**: https://my.ydea.cloud/app_api_v2

## Test Effettuati

### 1. Creazione Ticket con sla_id
```bash
./ydea-toolkit.sh api POST "/ticket" '{
  "anagrafica_id": 2339268,
  "titolo": "Test",
  "descrizione": "Test",
  "priorita_id": 30,
  "sla_id": 147
}'
```
**Risultato**: ✅ Ticket creato ma ❌ SLA non impostato

### 2. Verifica Campi Disponibili nel Ticket
```bash
curl GET "/ticket/1533729" | jq ".ticket | keys[]"
```
**Campi disponibili** (25 totali):
- anagrafica_id, assegnatoa, assetId, assetMatricola, codice, commessa
- contrattoCodice, contrattoId, customAttributes, dataChiusura
- dataCreazione, dataModifica, descrizione, erpCode, eventiPianificati
- fonte, id, link, priorita, priorita_id, ragioneSociale
- stato, stato_id, tipo, titolo, uuid

**Risultato**: ❌ Nessun campo relativo a SLA

### 3. Tentativi di Aggiornamento SLA
Testati tutti questi endpoint/metodi:
```bash
PATCH /ticket/1533729 {"sla_id": 147}           → 405 Method Not Allowed
PUT /ticket/1533729 {"sla_id": 147}             → 405 Method Not Allowed
POST /ticket/1533729/update {"sla_id": 147}     → 405 Method Not Allowed
POST /ticket/1533729/sla {"sla_id": 147}        → 405 Method Not Allowed
PUT /ticket/1533729/sla/147                     → 405 Method Not Allowed
POST /ticket/funzioni-commento-tipo/1533729     → 405 Method Not Allowed
```
**Risultato**: ❌ Tutti restituiscono 405 Method Not Allowed

### 4. Ricerca Endpoint SLA
```bash
GET /sla                → 404 Not Found (HTML error page)
GET /slas               → 404 Not Found (HTML error page)
GET /sla/147            → 404 Not Found
GET /priorita           → 404 Not Found
GET /ticket/fields      → 404 Not Found
GET /fields             → 404 Not Found
GET /metadata           → 404 Not Found
```
**Risultato**: ❌ Nessun endpoint SLA disponibile

### 5. Verifica Anagrafica
```bash
curl GET "/anagrafica/2339268" | jq "keys[]"
```
**Campi disponibili** (65 totali): agente1-5, anagrafica, cap, città, codici, contratti, dati fiscali, fax, email, telefono, ecc.

**Ricerca SLA**:
```bash
jq 'keys[] | select(test("sla|SLA|contratto|Contratto"))'
```
**Risultato**: ❌ Nessun campo SLA nell'anagrafica

### 6. Ricerca Valore 147
```bash
# Nel ticket
jq 'paths(scalars) as $p | select(getpath($p) == 147 or getpath($p) == "147")'

# Nell'anagrafica  
jq 'paths(scalars) as $p | select(getpath($p) == 147 or getpath($p) == "147")'
```
**Risultato**: ❌ Il valore 147 non compare in nessun campo

### 7. Test con contrattoId
```bash
POST /ticket {"contrattoId": 147, ...}
```
**Risultato**: ❌ `{"message":"Contratto non trovato"}` → 404

### 8. Ricerca Contratti
```bash
GET /contratto/147      → Testato
GET /servizio/147       → Testato
```
**Risultato**: ❌ Risorsa 147 non trovata

## Conclusioni

**Il campo SLA non è accessibile tramite API v2 di Ydea:**

1. Non esiste nel response di GET `/ticket/{id}`
2. Non è accettato in POST `/ticket` (parametro ignorato)
3. Non esistono endpoint `/sla`, `/slas` o simili
4. Non è presente nell'anagrafica
5. Tutti i metodi di update (PATCH/PUT) restituiscono 405
6. Il valore configurato (147) non corrisponde a nessuna risorsa API

## Domande per Supporto Ydea

1. **È possibile impostare il campo "Nome SLA" tramite API v2?**
   - Se sì, quale endpoint/campo utilizzare?
   - Qual è il nome corretto del parametro?

2. **Come ottenere l'ID corretto del SLA "Premium_Mon"?**
   - Esiste un endpoint per listare gli SLA disponibili?
   - L'ID 147 da dove deriva?

3. **Esiste una versione API v3 con supporto SLA?**
   - Se sì, qual è la documentazione?

4. **È possibile configurare SLA predefinito a livello anagrafica?**
   - In modo che i ticket ereditino automaticamente l'SLA del cliente

5. **Esistono regole automatiche lato server?**
   - Per impostare SLA in base a criteri (fonte, tipo ticket, anagrafica, ecc.)

## File di Configurazione Attuali

**Ydea-Toolkit/config/premium-mon-config.json**:
```json
{
  "sla_id": 147,
  "sla_nome": "Premium_Mon",
  "anagrafica_id": 2339268,
  "priorita_id": 30,
  "fonte": "Partner portal"
}
```

**Ydea-Toolkit/full/ydea-toolkit.sh** (linee 299-365):
```bash
create_ticket() {
    local sla_id="${4:-}"
    # ...
    if [[ -n "$sla_id" ]]; then
        json_body=$(echo "$json_body" | jq --arg sla "$sla_id" '. + {sla_id: $sla}')
    fi
    # POST /ticket
}
```

## Test Browser da Effettuare

Per confermare definitivamente, catturare il payload quando si crea un ticket manualmente:

1. Aprire DevTools (F12) → Tab Network
2. Filtrare per Fetch/XHR
3. Creare nuovo ticket con "Nome SLA" = "Premium_Mon"
4. Salvare il ticket
5. Nella richiesta POST `/ticket`, copiare il Request Payload completo

---

**Data ricerca**: 8 Dicembre 2025  
**API Version**: Ydea API v2  
**Esito**: SLA non disponibile via API

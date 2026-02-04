# Analisi Traffico HTTP YDEA - Creazione Ticket

## 📅 Data Analisi
**4 Febbraio 2026**

## 🎯 Obiettivo
Determinare come applicare correttamente uno SLA specifico (es. `Premium_Mon`) ai ticket YDEA creati via API o form HTML.

## 🔍 Metodo
1. Cattura traffico HTTP reale (HAR file) durante creazione ticket manuale
2. Estrazione dati POST dalla form HTML
3. Identificazione parametri critici per lo SLA

## 📊 Risultati Analisi HAR

### Endpoint Creazione Ticket
```
POST https://my.ydea.cloud/ticket/new
Content-Type: multipart/form-data
```

### Parametri Form Completi

```plaintext
appbundle_ticket[titolo]: "test"
appbundle_ticket[tipo]: "Server"
appbundle_ticket[priorita]: "30"
appbundle_ticket[fonte]: ""
appbundle_ticket[pagamento]: "61576"
appbundle_ticket[serviceLevelAgreement]: "147"    ← CHIAVE PER SLA!
appbundle_ticket[_token]: "<CSRF token dinamico>"

azienda: "2339268"                                 ← ID azienda
destinazione: "2831588"                            ← ID sede
contatto: ""
contratto: "171734"                                ← ID contratto con SLA
asset: "0"
condizioneAddebito: "C"
progetto: ""
files[]: ""
appbundle_ticket[descrizione]: ""
custom_attributes[int][3958]: "14553"
```

### 🔑 Parametri Critici per SLA

| Parametro | Valore Esempio | Descrizione | Obbligatorio? |
|-----------|----------------|-------------|---------------|
| `contratto` | 171734 | ID contratto che ha SLA configurato | ✅ Sì |
| `appbundle_ticket[serviceLevelAgreement]` | 147 | ID dello SLA da applicare | ❓ **DA TESTARE** |
| `appbundle_ticket[pagamento]` | 61576 | Modalità pagamento | ? |
| `azienda` | 2339268 | ID azienda cliente | ✅ Sì |
| `destinazione` | 2831588 | ID sede/destinazione | ? |

## 💡 Ipotesi

### Scenario A: Campo SLA Obbligatorio
Se `serviceLevelAgreement` è **obbligatorio**:
- ✅ Specificare ID SLA esplicito nel form
- ❌ Il contratto da solo non basta
- ⚠️ Problema: come ottenere ID SLA tramite API?

### Scenario B: Campo SLA Opzionale
Se `serviceLevelAgreement` è **opzionale**:
- ✅ Il contratto determina automaticamente lo SLA
- ✅ Più semplice per integrazione API
- ✅ Basta passare l'ID contratto corretto

## 🧪 Piano Test

Script creato: `test-ticket-creation-web.sh`

### Test 1: Con campo SLA esplicito
```bash
POST /ticket/new
  contratto: 171734
  serviceLevelAgreement: 147  ← Presente
```

**Verifica**: Ticket ha SLA `Premium_Mon`?

### Test 2: Senza campo SLA (solo contratto)
```bash
POST /ticket/new
  contratto: 171734
  serviceLevelAgreement: (omesso)  ← Assente
```

**Verifica**: Ticket ha SLA `Premium_Mon` o `Standard`?

### Interpretazione Risultati

| Test 1 | Test 2 | Conclusione |
|--------|--------|-------------|
| ✅ Premium_Mon | ✅ Premium_Mon | Campo SLA **OPZIONALE**, contratto basta |
| ✅ Premium_Mon | ❌ Standard | Campo SLA **NECESSARIO** |
| ❌ Errore | - | Campo SLA **OBBLIGATORIO** |

## 🔧 Implementazione

### Scenario A (SLA obbligatorio)
Necessaria chiamata API aggiuntiva per mappare:
```
Contratto ID → SLA ID
```

Possibili endpoint:
- `/contratto/{id}` → estrai `sla_id`
- `/azienda/{id}/contratti` → lista con SLA
- `/sla/list` → mappa contratti → SLA

### Scenario B (SLA opzionale)
Implementazione semplice:
```bash
# Basta passare contratto_id corretto
curl POST /ticket/new \
  -d "contratto=171734" \
  -d "azienda=2339268" \
  ...
```

## 📋 Dati di Test Validati

Dal HAR file, valori reali funzionanti:

```json
{
  "azienda": {
    "id": "2339268",
    "nome": "AZIENDA MONITORATA test"
  },
  "contratto": {
    "id": "171734",
    "sla": "Premium_Mon"
  },
  "sla": {
    "id": "147",
    "nome": "Premium_Mon"
  },
  "destinazione": {
    "id": "2831588"
  }
}
```

## ⚠️ Note Implementazione

### CSRF Token
- Token dinamico nel campo `appbundle_ticket[_token]`
- Deve essere estratto dalla pagina `/ticket/new` prima del POST
- Cambia ad ogni richiesta
- Necessario per sicurezza

### Autenticazione
- Login via `POST /login_check`
- Cookie di sessione persistente
- Necessario per tutte le operazioni

### Content-Type
- **Form HTML**: `multipart/form-data` (analizzato qui)
- **API JSON**: `application/json` (testato precedentemente)
- Entrambi supportati da YDEA

## 🎯 Prossimi Passi

1. ✅ Eseguire `test-ticket-creation-web.sh`
2. ✅ Verificare risultati su UI YDEA
3. ✅ Determinare se campo SLA è necessario
4. ⏭️ Implementare logica finale in `create-ticket-with-contract.sh`

## 📚 File Correlati

- **Script test**: `Ydea-Toolkit/full/test-ticket-creation-web.sh`
- **README**: `Ydea-Toolkit/full/README-test-web.md`
- **Config template**: `Ydea-Toolkit/config/credentials.sh.template`
- **HAR originale**: `my.ydea.cloud.har` (sul desktop, non committato)

## 🔗 Riferimenti

- **HAR Format**: HTTP Archive format per DevTools
- **YDEA Base URL**: https://my.ydea.cloud
- **Docs YDEA API**: (non disponibile pubblicamente)

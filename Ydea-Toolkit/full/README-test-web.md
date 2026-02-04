# Test Creazione Ticket YDEA via Form HTML

## 📋 Descrizione

Script per testare la creazione di ticket YDEA usando il **form HTML reale** invece delle API JSON.

I dati sono stati estratti da un HAR file catturato durante la creazione manuale di un ticket tramite browser.

## 🎯 Obiettivo

Determinare se il campo `serviceLevelAgreement` è:
- **NECESSARIO** per applicare lo SLA corretto al ticket
- **OPZIONALE** (lo SLA viene automaticamente applicato dal contratto)

## 🔧 Configurazione

### 1. Crea file credenziali

```bash
cd Ydea-Toolkit/config
cp credentials.sh.template credentials.sh
```

### 2. Modifica `credentials.sh` con i tuoi dati

```bash
# Credenziali login
YDEA_USERNAME="tuo@email.com"
YDEA_PASSWORD="tua-password"

# IDs dal tuo ambiente
YDEA_AZIENDA_ID="123456"      # ID azienda di test
YDEA_DESTINAZIONE_ID="789"     # ID sede
YDEA_CONTRACT_ID="456"         # ID contratto con SLA
YDEA_SLA_ID="147"              # ID SLA Premium_Mon
```

### 3. Come trovare gli IDs

#### Metodo 1: Ispeziona form su YDEA
1. Vai su https://my.ydea.cloud/ticket/new
2. Apri DevTools → Tab Network
3. Seleziona un'azienda con contratto
4. Guarda le chiamate POST per vedere gli ID passati

#### Metodo 2: Cattura HAR file
1. DevTools → Tab Network
2. Compila form ticket manualmente
3. Clicca "Salva" (ma **NON chiudere DevTools**)
4. Export HAR file: Right-click → "Save all as HAR"
5. Cerca nel HAR i valori di:
   - `azienda`: ID azienda
   - `destinazione`: ID sede
   - `contratto`: ID contratto
   - `serviceLevelAgreement`: ID SLA

## 🚀 Utilizzo

```bash
cd Ydea-Toolkit/full
./test-ticket-creation-web.sh
```

### Output atteso

```
════════════════════════════════════════════════════════════════════
🧪 TEST CREAZIONE TICKET YDEA - Via Form HTML
════════════════════════════════════════════════════════════════════

🔐 Login a YDEA...
   Token CSRF: YXBwYnVuZGxlX3RpY2tl...
✅ Login riuscito!

════════════════════════════════════════════════════════════════════
🧪 TEST 1: Ticket con contratto SLA Premium_Mon
════════════════════════════════════════════════════════════════════

────────────────────────────────────────────────────────────────────
📝 Creazione ticket: [TEST] Contratto Premium_Mon
   Contratto: 171734
   SLA: 147
────────────────────────────────────────────────────────────────────
🔍 Estrazione CSRF token da /ticket/new...
   Token form: YXBwYnVuZGxlX3RpY2tldHwxNzcwMjAxMjAwLjUxNT...
✅ Ticket creato: ID 1630567
🔗 URL: https://my.ydea.cloud/ticket/1630567

════════════════════════════════════════════════════════════════════
🧪 TEST 2: Ticket SENZA campo SLA (solo contratto)
════════════════════════════════════════════════════════════════════

────────────────────────────────────────────────────────────────────
📝 Creazione ticket: [TEST] Solo contratto, no SLA esplicito
   Contratto: 171734
────────────────────────────────────────────────────────────────────
🔍 Estrazione CSRF token da /ticket/new...
   Token form: YXBwYnVuZGxlX3RpY2tldHwxNzcwMjAxMzAwLjQyMz...
✅ Ticket creato: ID 1630568
🔗 URL: https://my.ydea.cloud/ticket/1630568

════════════════════════════════════════════════════════════════════
✅ Test completati!

📋 VERIFICA MANUALE su YDEA:
   1. Vai su https://my.ydea.cloud
   2. Controlla i 2 ticket appena creati
   3. Verifica quale ha SLA 'Premium_Mon' attivo

💡 Questo ti dirà se il campo 'serviceLevelAgreement' è:
   - NECESSARIO per applicare lo SLA corretto
   - OPZIONALE (lo SLA viene preso dal contratto)
════════════════════════════════════════════════════════════════════
```

## 🔍 Verifica Risultati

Dopo l'esecuzione, **vai su YDEA** e controlla:

1. **Ticket 1** (con campo SLA esplicito):
   - Ha SLA `Premium_Mon`? ✅ Campo funziona
   
2. **Ticket 2** (senza campo SLA):
   - Ha SLA `Premium_Mon`? ✅ Campo opzionale, contratto basta
   - Ha SLA `Standard`? ❌ Campo SLA è **necessario**

## 📊 Dati Form Estratti dal HAR

Il POST usa `multipart/form-data` con questi campi:

```
appbundle_ticket[titolo]: "test"
appbundle_ticket[tipo]: "Server"
appbundle_ticket[priorita]: "30"
appbundle_ticket[fonte]: ""
appbundle_ticket[pagamento]: "61576"
appbundle_ticket[serviceLevelAgreement]: "147"  ← DA TESTARE
appbundle_ticket[_token]: "<CSRF token dinamico>"
azienda: "2339268"
destinazione: "2831588"
contatto: ""
contratto: "171734"
asset: "0"
condizioneAddebito: "C"
progetto: ""
files[]: ""
appbundle_ticket[descrizione]: ""
custom_attributes[int][3958]: "14553"
```

## ⚠️ Note Sicurezza

- **NON committare** `credentials.sh` (già in .gitignore)
- I cookie di sessione sono salvati in `.ydea-cookies` (escluso da git)
- Il token CSRF è **dinamico** e viene estratto ad ogni richiesta
- Script usa **HTTPS** per tutte le comunicazioni

## 🐛 Troubleshooting

### Login fallito
```bash
# Verifica credenziali
cat config/credentials.sh

# Prova login manuale sul browser
open https://my.ydea.cloud/login
```

### Token CSRF non trovato
```bash
# Verifica che la pagina sia accessibile
curl -s https://my.ydea.cloud/ticket/new | grep "_token"
```

### Ticket non creato
```bash
# Abilita verbose output
bash -x test-ticket-creation-web.sh 2>&1 | tee debug.log

# Controlla HTTP response
grep "HTTP_CODE" debug.log
```

## 📚 Riferimenti

- **HAR File**: Formato JSON per export traffico HTTP DevTools
- **CSRF**: Token anti-falsificazione richiesto da YDEA
- **Multipart Form Data**: Encoding per upload file e form complessi

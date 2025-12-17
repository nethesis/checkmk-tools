# Ydea SLA Discovery Tool

## 📋 Descrizione
Script per identificare gli ID delle categorie, sottocategorie e SLA personalizzata necessari per la gestione automatica dei ticket di monitoraggio CheckMK con SLA Premium_Mon.

## 🎯 Obiettivo
Trovare gli ID per:
- **Macro categoria**: `Premium_Mon`
- **8 Sottocategorie**:
  - Centrale telefonica NethVoice
  - Firewall UTM NethSecurity
  - Collaboration Suite NethService
  - Computer client
  - Server
  - Apparati di rete - Networking
  - Hypervisor
  - Consulenza tecnica specialistica
- **SLA personalizzata**: `TK25/003209 SLA Personalizzata`
- **Priorità bassa**: per i ticket di monitoraggio

## 📁 File
- **Script principale**: `full/ydea-discover-sla-ids.sh`
- **Launcher remoto**: `remote/rydea-discover-sla-ids.sh`
- **Output**: `full/sla-premium-mon-ids.json`

## 🚀 Utilizzo

### Esecuzione locale (da repository)
```bash
cd /path/to/checkmk-tools/Ydea-Toolkit/full
./ydea-discover-sla-ids.sh
```

### Esecuzione remota (su server CheckMK)
```bash
# Dopo aver deployato gli script con auto-git-sync
/opt/checkmk-tools/Ydea-Toolkit/remote/rydea-discover-sla-ids.sh
```

## 📝 Output
Lo script crea un file `sla-premium-mon-ids.json` con la seguente struttura:

```json
{
  "discovery_date": "2025-12-04 10:30:00",
  "description": "ID per gestione ticket con SLA Premium_Mon",
  "macro_category": {
    "id": 123,
    "name": "Premium_Mon"
  },
  "subcategories": [
    {
      "name": "Centrale telefonica NethVoice",
      "id": 456
    },
    {
      "name": "Firewall UTM NethSecurity",
      "id": 457
    }
    // ... altre sottocategorie
  ],
  "sla": {
    "id": 789,
    "name": "TK25/003209 SLA Personalizzata"
  },
  "low_priority": {
    "id": 1,
    "name": "Bassa"
  }
}
```

## 🔍 File di Debug
Durante l'esecuzione vengono creati anche file di dump completo per debug:
- `categories-full-dump.json` - Tutte le categorie disponibili
- `sla-full-dump.json` - Tutte le SLA disponibili
- `priorities-full-dump.json` - Tutte le priorità disponibili

Questi file sono utili per verificare manualmente i dati disponibili nell'API Ydea.

## ⚙️ Prerequisiti
1. **Credenziali configurate** nel file `.env`:
   ```bash
   YDEA_ID="your_id"
   YDEA_API_KEY="your_api_key"
   ```

2. **Dipendenze**:
   - `jq` - per il parsing JSON
   - `curl` - per le chiamate API
   - `ydea-toolkit.sh` - libreria principale

## ✅ Verifica Risultati
Lo script verifica automaticamente se tutti gli elementi richiesti sono stati trovati:
- ✅ Tutti trovati → exit code 0
- ⚠️ Elementi mancanti → exit code 1 con lista di ciò che manca

## 🔄 Integrazione con CheckMK
Dopo aver ottenuto gli ID, il prossimo passo è:
1. Integrare questi ID negli script di notifica CheckMK
2. Implementare la logica di mapping: tipo allarme → sottocategoria appropriata
3. Configurare la creazione automatica ticket con SLA Premium_Mon

## 📚 Riferimenti
- **Cliente**: TK25/003209
- **Contratto**: Monitoraggio con SLA Personalizzata
- **Priorità default**: Bassa
- **Categoria**: Premium_Mon

## 🔧 Troubleshooting

### Errore autenticazione
```
❌ Impossibile autenticarsi a Ydea API
```
**Soluzione**: Verifica che `YDEA_ID` e `YDEA_API_KEY` siano correttamente impostati nel file `.env`

### Categoria non trovata
```
⚠️ Macro categoria 'Premium_Mon' non trovata direttamente
```
**Soluzione**: Controlla il file `categories-full-dump.json` per verificare il nome esatto della categoria nell'API

### SLA non trovata
```
⚠️ SLA 'TK25/003209 SLA Personalizzata' non trovata
```
**Soluzione**: 
- Verifica che la SLA sia stata creata in Ydea
- Controlla il file `sla-full-dump.json` per vedere tutte le SLA disponibili
- Lo script prova anche una ricerca parziale per "TK25/003209"

## 📊 Esempio Output Completo
```
═══════════════════════════════════════════════════════════════
  🔍 YDEA SLA DISCOVERY TOOL
═══════════════════════════════════════════════════════════════

ℹ️  Inizio discovery per SLA Premium_Mon...
ℹ️  Output verrà salvato in: /path/to/sla-premium-mon-ids.json
✅ Autenticazione completata

═══════════════════════════════════════════════════════════════
  🔍 DISCOVERY CATEGORIE E SOTTOCATEGORIE
═══════════════════════════════════════════════════════════════

ℹ️  Recupero lista categorie da Ydea API...
✅ Macro categoria 'Premium_Mon' trovata → ID: 123

ℹ️  Ricerca sottocategorie...

  ✅ 'Centrale telefonica NethVoice' → ID: 456
  ✅ 'Firewall UTM NethSecurity' → ID: 457
  ✅ 'Collaboration Suite NethService' → ID: 458
  ✅ 'Computer client' → ID: 459
  ✅ 'Server' → ID: 460
  ✅ 'Apparati di rete - Networking' → ID: 461
  ✅ 'Hypervisor' → ID: 462
  ✅ 'Consulenza tecnica specialistica' → ID: 463

ℹ️  Sottocategorie trovate: 8/8

═══════════════════════════════════════════════════════════════
  📝 GENERAZIONE FILE CONFIGURAZIONE
═══════════════════════════════════════════════════════════════

✅ File di configurazione creato: /path/to/sla-premium-mon-ids.json

Contenuto:
{
  "discovery_date": "2025-12-04 10:30:00",
  "description": "ID per gestione ticket con SLA Premium_Mon",
  "macro_category": {
    "id": 123,
    "name": "Premium_Mon"
  },
  "subcategories": [...],
  "sla": {
    "id": 789,
    "name": "TK25/003209 SLA Personalizzata"
  }
}

✅ 🎉 Tutti gli elementi richiesti sono stati trovati!

ℹ️  Prossimi passi:
  1. Verifica il contenuto di: /path/to/sla-premium-mon-ids.json
  2. Integra questi ID negli script di notifica CheckMK
  3. Implementa la logica di mapping sottocategoria → tipo allarme
```

## 🔜 Prossimi Sviluppi
1. **Script di creazione ticket** con SLA Premium_Mon
2. **Mapping automatico** allarme CheckMK → sottocategoria
3. **Template ticket** specifici per tipo di servizio monitorato
4. **Gestione priorità dinamica** basata su criticità allarme

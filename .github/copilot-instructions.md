# GitHub Copilot Instructions - checkmk-tools

## 🔧 Strumenti di Controllo Qualità

### check-integrity.ps1 - Controllo Integrità Repository

**Quando usare questo strumento:**
- Quando l'utente chiede di "controllare l'integrità" o "verificare la corruzione"
- Dopo modifiche massive a script bash o PowerShell
- Prima di merge importanti
- Quando sospetti corruzione file nel repository

**Comandi disponibili:**

```powershell
# Controllo standard con riepilogo
.\check-integrity.ps1

# Controllo dettagliato con lista completa errori
.\check-integrity.ps1 -Detailed

# Esporta report completo su file
.\check-integrity.ps1 -ExportReport

# Cambia soglia di corruzione (default: 15%)
.\check-integrity.ps1 -Threshold 20
```

**Funzionalità:**
- ✅ Verifica sintassi **PowerShell** tramite `[System.Management.Automation.Language.Parser]::ParseFile()`
- ✅ Verifica sintassi **Bash/Shell** tramite WSL `bash -n`
- ✅ Rileva **corruzione massiva** (soglia default: 15%)
- ✅ Report dettagliato per tipo di file (PS1, Bash, Batch, Python)
- ✅ Exit codes: 0=OK, 1=Warning (<15%), 2=Critical (>15%)

**Integrazione con Sistema di Backup:**
- `backup-simple.ps1` usa la stessa logica di validazione
- Il backup viene **bloccato** se la corruzione supera il 15%
- Le email di backup includono report dettagliato degli errori rilevati

**Struttura Repository Verificata:**
```
checkmk-tools/
├── script-check-ns7/full/         # Script NethServer 7
├── script-check-ns8/full/         # Script NethServer 8
├── script-check-proxmox/full/     # Script Proxmox
├── script-check-ubuntu/full/      # Script Ubuntu
├── script-tools/full/             # Tools vari
├── script-notify-checkmk/full/    # Notifiche CheckMK
└── Ydea-Toolkit/full/             # Integrazione Ydea
```

**Output Esempio:**
```
================================================================
    RISULTATI VERIFICA INTEGRITÀ
================================================================

RIEPILOGO GENERALE:
  Script verificati:    451
  Script validi:        387
  Script con errori:    64
  Percentuale errori:   14.19%
  Soglia corruzione:    15%

DETTAGLIO PER TIPO:
  Bash/Shell
    Totale:      416
    Validi:      352
    Errori:      64 (15.4%)

[STATO] WARNING - Errori rilevati ma sotto soglia
```

---

## 🎯 Workflow Consigliato

### ⚠️ REGOLA OBBLIGATORIA - Validazione Script
**SEMPRE quando crei o modifichi uno script Bash/Shell:**
1. ✅ Testa con `wsl bash -n <file_path>` 
2. ✅ Verifica che `$LASTEXITCODE -eq 0`
3. ✅ Se exit code ≠ 0, correggi gli errori e ritesta
4. ✅ Ripeti finché non ottieni exit code 0
5. ✅ Solo allora considera il file completato

**Comando PowerShell da usare:**
```powershell
wsl bash -n "path/to/script.sh"; echo "EXIT CODE: $LASTEXITCODE"
```

**Non procedere mai senza exit code 0!**
### 📂 REGOLA DEPLOYMENT - Path Script dal Repository GitHub

**Gli script devono SEMPRE essere eseguiti dal repository locale clonato da GitHub:**
- ❌ NON copiare script in `/usr/local/bin` o `/usr/bin`
- ❌ NON creare copie in cartelle di sistema
- ✅ Esegui direttamente dal clone git del repository GitHub
- ✅ Path base repository: `/opt/checkmk-tools` (git clone da GitHub)
- ✅ Repository GitHub: `https://github.com/Coverup20/checkmk-tools.git`

**Setup repository sul server:**
```bash
# Prima installazione sul server
cd /opt
git clone https://github.com/Coverup20/checkmk-tools.git

# Aggiornamenti successivi
cd /opt/checkmk-tools
git pull
```

**Esempi corretti per cron/systemd:**
```bash
# Cron job - path assoluta dal repository locale (clone GitHub)
0 3 * * * /opt/checkmk-tools/script-tools/full/cleanup-checkmk-retention.sh >> /var/log/script.log 2>&1

# Esecuzione manuale - path assoluta dal repository
/opt/checkmk-tools/script-tools/full/script-name.sh

# Systemd ExecStart - path assoluta dal repository
ExecStart=/opt/checkmk-tools/script-tools/full/script-name.sh
```

**Vantaggi:**
- ✅ Aggiornamenti automatici con `git pull` dal repository GitHub
- ✅ Versioning e rollback tramite git
- ✅ Single source of truth (repository GitHub)
- ✅ Nessuna sincronizzazione manuale necessaria
- ✅ Tutti i server usano stessa versione da GitHub
### Prima di ogni commit importante:
1. Eseguire `.\check-integrity.ps1` per verificare lo stato
2. Se errori >15%, indagare prima di committare
3. Verificare che tutti gli script .sh siano eseguibili

### Dopo modifiche massive:
1. Eseguire `.\check-integrity.ps1 -Detailed` per vedere tutti gli errori
2. Valutare se è necessario riparare script corrotti
3. Usare `.\repair-corrupted-scripts.ps1` se disponibile

### Monitoraggio periodico:
- **Settimanale**: `.\check-integrity.ps1 -ExportReport` per storico
- **Mensile**: Analizzare trend corruzione nel tempo

---

## 📚 Strumenti Correlati

- **backup-simple.ps1**: Usa stessa logica per backup sicuri
- **repair-corrupted-scripts.ps1**: Riparazione automatica script corrotti
- **WSL**: Necessario per validazione Bash (`bash -n`)

---

**Ultimo aggiornamento**: 2026-01-22

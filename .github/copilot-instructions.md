# GitHub Copilot Instructions - checkmk-tools

## ⚠️ REGOLE DI SICUREZZA OBBLIGATORIE

### 🛡️ Protezione Dati e Conferme

**SEMPRE rispettare queste regole:**

1. **Un comando alla volta**
   - ❌ NON eseguire comandi multipli senza conferma
   - ✅ Eseguire un comando, attendere conferma utente
   - ⚠️ SPECIALMENTE per operazioni distruttive (rm, delete, drop, truncate)

2. **Backup prima di cancellare**
   - ❌ NON cancellare mai file/directory senza backup
   - ✅ SEMPRE creare backup prima di operazioni distruttive
   - ✅ Formato backup: `NOME_ORIGINALE.backup_YYYY-MM-DD_HH-MM-SS`
   - ✅ Confermare path backup all'utente prima di procedere

3. **Conferma operazioni critiche**
   - Cancellazioni
   - Modifiche massive (>10 file)
   - Deploy su produzione
   - Comandi su sistemi remoti

4. **Verifica preferenze Copilot periodicamente**
   - ✅ Controllare `.github/copilot-instructions.md` regolarmente
   - ✅ Assicurarsi di seguire sempre le ultime istruzioni
   - ✅ Suggerire aggiornamenti quando necessario

5. **Memorizza informazioni utili**
   - ✅ Se scopri pattern/comandi/procedure utili → aggiungili alle copilot-instructions
   - ✅ Workflow che funzionano bene vanno documentati
   - ✅ Path comuni, configurazioni standard, troubleshooting tips

6. **Pulizia backup dopo test**
   - ✅ Quando i test su file backuppati terminano con successo
   - ✅ Proporre rimozione dei file backup creati
   - ✅ ATTENDERE conferma utente prima di eliminare
   - ✅ Non eliminare mai backup senza conferma esplicita

7. **Controllo integrità periodico automatico**
   - ✅ Durante le conversazioni, proporre periodicamente `.\check-integrity.ps1 -SendEmail`
   - ✅ Eseguire il controllo in momenti opportuni (dopo modifiche, commit importanti, richieste utente)
   - ✅ Inviare email se anche solo 1 file corrotto viene trovato
   - ✅ Email include: lista file corrotti, percentuale errori, dettagli
   - ✅ Non inviare email se tutto OK (solo output console)

**Esempio workflow corretto:**
```bash
# 1. Backup
cp file.txt file.txt.backup_2026-01-27_20-30-00

# 2. Chiedi conferma
"Ho creato backup in file.txt.backup_2026-01-27_20-30-00. Procedo con cancellazione?"

# 3. Solo dopo OK utente
rm file.txt
```

---

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

**Gli script devono SEMPRE essere eseguiti direttamente dal repository GitHub con curl:**
- ❌ NON copiare script in `/usr/local/bin` o `/usr/bin`
- ❌ NON creare copie locali o git clone
- ✅ Esegui direttamente da GitHub tramite curl/wget
- ✅ Repository GitHub: `https://github.com/Coverup20/checkmk-tools.git`
- ✅ Raw URL base: `https://raw.githubusercontent.com/Coverup20/checkmk-tools/main`

**Esempi corretti per cron/systemd:**
```bash
# Cron job - esecuzione diretta da GitHub
0 3 * * * curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/cleanup-checkmk-retention.sh | bash >> /var/log/script.log 2>&1

# Esecuzione manuale - scarica ed esegui da GitHub
curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/script-name.sh | bash

# Systemd ExecStart - esecuzione diretta da GitHub
ExecStart=/bin/bash -c "curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/script-name.sh | bash"
```

**Vantaggi:**
- ✅ Sempre l'ultima versione da GitHub (no git pull necessario)
- ✅ Nessun repository locale da mantenere
- ✅ Single source of truth: repository GitHub
- ✅ Tutti i server usano identica versione in tempo reale
- ✅ Zero sincronizzazione manuale
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

## 🔧 Agent CheckMK - Installazione/Aggiornamento

**⚠️ IMPORTANTE: Usare sempre lo script dedicato per agent CheckMK**

### Script da usare:
```bash
# Su server remoti CheckMK
/opt/checkmk-tools/script-tools/full/install-agent-interactive.sh

# Da GitHub (se repo non clonato)
curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/install-agent-interactive.sh | bash
```

### Cosa fa lo script:
- ✅ Rileva OS automaticamente (Debian/Ubuntu/RHEL/OpenWrt)
- ✅ Scarica agent corretto dalla versione CheckMK server
- ✅ **Disabilita automaticamente `cmk-agent-ctl-daemon.service`** (causa conflitti porta 6556)
- ✅ Configura socket TCP plain su porta 6556
- ✅ Gestisce correttamente systemd/xinetd/procd
- ✅ Opzionale: configura FRPC per tunnel

### Problema comune:
**NON usare solo `dpkg -i check-mk-agent.deb`** perché:
- ❌ Lascia attivo `cmk-agent-ctl-daemon` che va in conflitto
- ❌ Non configura correttamente il socket TCP
- ❌ Causa errore "Address in use (os error 98)"

### Fix se già installato manualmente:
```bash
# Disabilita daemon problematico
systemctl disable --now cmk-agent-ctl-daemon.service
systemctl reset-failed cmk-agent-ctl-daemon.service

# L'agent continua a funzionare via check-mk-agent.socket
```

---

## 🔌 Accesso Remoto SSH - VPS e Server Locali

### Setup WSL SSH

**Environment configurato:**
- ✅ WSL: Ubuntu su Windows (`wsl -- bash -c "command"`)
- ✅ SSH Keys: `~/.ssh/checkmk` (protetta da passphrase)
- ✅ SSH Config: `~/.ssh/config` con alias host
- ✅ SSH ControlMaster: Riutilizzo connessioni (passphrase 1 volta, poi 10 min attiva)

**Host disponibili:**

```bash
# VPS CheckMK (chiave: ~/.ssh/checkmk + passphrase)
checkmk-vps-01    # monitor.nethlab.it (CheckMK 2.4.0p19.cre)
checkmk-vps-02    # monitor01.nethlab.it
checkmk-vps03     # 143.110.148.110

# Server locali CheckMK (autenticazione password)
checkmk-z1plus    # 192.168.10.128 (locale)
checkmk-testfrp   # 192.168.10.126 (user: admin_nethesis)

# Server locali altri (autenticazione password)
ns-lab00          # 192.168.10.100:2222 (root)

# Altri server (chiave: ~/.ssh/sos-openssh)
sos               # sos.nethesis.it (user: marzio)
fwlab             # 192.168.5.117:2222 (root)
redteam           # redteam.security.nethesis.it (root)
```

### 🚀 Workflow Accesso Remoto

**1. Comando singolo SSH:**
```powershell
# Da PowerShell → esegui comando su VPS
wsl -- ssh checkmk-vps-01 "omd version"
wsl -- ssh checkmk-vps-02 "omd sites"
wsl -- ssh checkmk-vps03 "systemctl status omd"
```

**2. Esecuzione script da GitHub:**
```powershell
# Download ed esecuzione diretta script dal repository
wsl -- ssh checkmk-vps-01 "curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/cleanup-checkmk-retention.sh | bash"

# Con parametri
wsl -- ssh checkmk-vps-01 "curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/script.sh | bash -s -- arg1 arg2"
```

**3. Verifica stato CheckMK remoto:**
```powershell
# Check rapido su tutti i VPS
wsl -- ssh checkmk-vps-01 "omd status"
wsl -- ssh checkmk-vps-02 "omd status"
wsl -- ssh checkmk-vps03 "omd status"

# Verifica backup
wsl -- ssh checkmk-vps-01 "ls -lh /opt/omd/sites/monitoring/var/check_mk/notify-backup/"
```

**4. Deploy script su VPS:**
```powershell
# NON copiare file, eseguire sempre da GitHub!
# ❌ SBAGLIATO: scp script.sh checkmk-vps-01:/usr/local/bin/
# ✅ CORRETTO: esegui da GitHub con curl

wsl -- ssh checkmk-vps-01 "curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/cleanup-checkmk-retention.sh | bash"
```

### 🔐 Note Sicurezza

- **Passphrase**: Le chiavi richiedono passphrase ad ogni comando
  - Non è un problema: inserire passphrase quando richiesta
  - Protegge accesso non autorizzato
  
- **StrictHostKeyChecking no**: Disabilitato per automazione
  - OK per ambiente lab/interno
  - Valutare riabilitazione per produzione

### 🎯 Use Cases Comuni

**Controllo integrità remoto:**
```powershell
# Esegui check-integrity su VPS
wsl -- ssh checkmk-vps-01 "curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/cleanup-checkmk-retention.sh | bash -n"
```

**Verifica logs:**
```powershell
wsl -- ssh checkmk-vps-01 "tail -100 /omd/sites/monitoring/var/log/notify.log"
```

**Raccolta info sistema:**
```powershell
wsl -- ssh checkmk-vps-01 "df -h && free -h && uptime"
```

### ⚙️ Path Chiavi e Config

```bash
# WSL paths
~/.ssh/checkmk              # Chiave privata VPS (con passphrase)
~/.ssh/sos-openssh          # Chiave privata altri server
~/.ssh/config               # Configurazione SSH
~/.ssh/known_hosts          # Host verificati

# Windows paths originali (backup)
C:\Users\Marzio\.ssh\checkmk
C:\Users\Marzio\.ssh\sos-openssh
```

---

**Ultimo aggiornamento**: 2026-01-27

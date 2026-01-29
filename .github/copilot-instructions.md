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
8. **Recupero script corrotti o persi**
   - ✅ **Metodo 1**: Git history - `git log`, `git show`, `git checkout`
   - ✅ **Metodo 2**: Backup locali - `C:\CheckMK-Backups\<timestamp>\`
   - ✅ **Metodo 3**: Backup rete - `\\192.168.10.132\usbshare\CheckMK-Backups\<timestamp>\`
   - ⚠️ Verificare **sempre** disponibilità backup prima di modifiche massive
   - ✅ Backup automatici eseguiti daily: job00 (locale+rete), ultra-minimal (locale)

**Esempio recupero file:**
```powershell
# Da Git (commit precedente)
git show HEAD~1:script-tools/full/script.sh > script.sh.recovered

# Da backup locale
Copy-Item "C:\CheckMK-Backups\2026-01-29_03-00-00\script-tools\full\script.sh" -Destination ".\"

# Da backup rete
Copy-Item "\\192.168.10.132\usbshare\CheckMK-Backups\2026-01-29_00-00-00\script-tools\full\script.sh" -Destination ".\"
```

9. **Test-Fix-Validate Loop Automatico**
   - ✅ Quando modifichiamo uno script E abbiamo accesso a host di test
   - ✅ **SEMPRE** seguire questo ciclo automatico dopo ogni modifica:
     1. **Modifica** script
     2. **Valida** sintassi (`bash -n` o PSParser)
     3. **Testa** su host remoto (esecuzione reale)
     4. **Se fallisce** → Fix errore
     5. **Ri-valida** sintassi
     6. **Ri-testa** su host
     7. **Ripeti** finché non funziona o finché utente non ferma
   - ⚠️ **NON fermarsi** dopo validazione sintassi se test fallisce
   - ⚠️ **NON aspettare** comando utente per fixare - fallo automaticamente
   - ✅ **Continuare** a iterare fino a successo completo

**Esempio workflow test-driven:**
```powershell
# 1. Modifica script
# ... edit file ...

# 2. Valida sintassi
wsl bash -n script.sh  # EXIT CODE: 0 ✓

# 3. Testa su host
wsl -- ssh nsec8-stable "bash /opt/checkmk-tools/script.sh"
# Output: ERROR line 45: comando non trovato

# 4. Fix automatico (NON fermarsi!)
# ... correggi errore linea 45 ...

# 5. Ri-valida
wsl bash -n script.sh  # EXIT CODE: 0 ✓

# 6. Ri-testa
wsl -- ssh nsec8-stable "bash /opt/checkmk-tools/script.sh"
# Output: SUCCESS ✓

# 7. Solo ora committa
git commit -m "fix: risolto errore comando"
```

**Host disponibili per test:**
- `nsec8-stable` (10.155.100.100) - NethSecurity 8 test environment
- `checkmk-vps-02` (monitor01.nethlab.it) - CheckMK staging/test
- `checkmk-z1plus` (192.168.10.128) - CheckMK locale test

---

## �️ NethServer - Gestione Configurazione

### ⚠️ REGOLA CRITICA - NON modificare file di configurazione manualmente

**NethServer (NS7/NS8) usa sistema e-smith/template:**
- ❌ **MAI modificare direttamente** file in `/etc/` (fail2ban, httpd, postfix, etc.)
- ✅ **SEMPRE usare interfaccia web** o comandi `config`
- ⚠️ Modifiche manuali ai file = **perse al prossimo `signal-event`**

**Esempio configurazioni gestite da template:**
```bash
/etc/fail2ban/fail2ban.conf          # Gestito da templates
/etc/fail2ban/jail.conf              # Gestito da templates
/etc/httpd/conf.d/*                  # Gestito da templates
/etc/postfix/main.cf                 # Gestito da templates
/etc/shorewall/*                     # Gestito da templates
```

**Metodi corretti per modificare configurazioni:**

1. **Via interfaccia web NethServer**
   - Server Manager → sezione specifica
   - Modifiche persistenti e validate

2. **Via comandi config (CLI)**
```bash
# Visualizza configurazione
config show fail2ban

# Modifica proprietà
config setprop fail2ban LogLevel NOTICE
config setprop fail2ban DbPurgeAge 30d

# Applica modifiche
signal-event nethserver-fail2ban-save
```

3. **Via template custom** (avanzato)
```bash
# Crea template custom in /etc/e-smith/templates-custom/
# Le modifiche sopravvivono ai signal-event
```

**⚠️ Conseguenze modifiche manuali:**
- `signal-event nethserver-<servizio>-save` → configurazione ripristinata
- Riavvio servizio → configurazione ripristinata
- Aggiornamenti sistema → configurazione ripristinata

**✅ SEMPRE chiedere conferma utente** prima di suggerire modifiche manuali a file su NethServer!

---

## �🔧 Strumenti di Controllo Qualità

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

#### Bash/Shell Script
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

#### PowerShell Script (.ps1)
**SEMPRE quando crei o modifichi uno script PowerShell:**
1. ✅ Valida con PSParser
2. ✅ Verifica che errori count = 0
3. ✅ Se errori presenti, correggi e ritesta
4. ✅ Ripeti finché non ottieni 0 errori
5. ✅ Solo allora considera il file completato

**Comando validazione da usare:**
```powershell
$errors = $null; $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content "path/to/script.ps1" -Raw), [ref]$errors); if ($errors.Count -eq 0) { Write-Host "Sintassi OK" -ForegroundColor Green } else { Write-Host "ERRORI:" -ForegroundColor Red; $errors }; Write-Host "EXIT CODE: $LASTEXITCODE"
```

**Errori comuni PowerShell:**
- ❌ Carattere `%` non escaped in stringhe → Usare `$($variabile)%`
- ❌ Regex anchor `\z` → Preferire `$` (più compatibile)
- ❌ Apici/virgolette non chiuse correttamente

**Non procedere mai se PSParser riporta errori!**
### 📂 REGOLA DEPLOYMENT - Path Script Repository

**⚠️ IMPORTANTE: Repository già clonato su tutte le macchine**

**Path repository locale:**
- ✅ **TUTTE le macchine (server e host) hanno git clone in `/opt/checkmk-tools/`**
- ✅ Repository aggiornato automaticamente (git pull automatico)
- ✅ Preferire esecuzione locale quando disponibile (più comodo/veloce)
- ⚠️ **ATTENZIONE: Il clone locale è READ-ONLY** - qualsiasi modifica viene sovrascritta dal git pull automatico
- ❌ **MAI modificare file in `/opt/checkmk-tools/`** - modifiche si perdono sistematicamente

**Ordine di priorità:**
1. **Locale (se disponibile)**: `/opt/checkmk-tools/script-tools/full/script-name.sh` (più comodo)
2. **GitHub raw**: `https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/...` (funziona ugualmente bene)

**Esempi esecuzione locale:**
```bash
# Esecuzione diretta da repo locale
/opt/checkmk-tools/script-tools/full/install-agent-interactive.sh

# Cron job - usa repo locale
0 3 * * * /opt/checkmk-tools/script-tools/full/cleanup-checkmk-retention.sh >> /var/log/script.log 2>&1

# Con bash esplicito
bash /opt/checkmk-tools/script-tools/full/script-name.sh
```

**Esempi esecuzione da GitHub (fallback o host remoti):**
```bash
# Cron job - esecuzione diretta da GitHub
0 3 * * * curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/cleanup-checkmk-retention.sh | bash >> /var/log/script.log 2>&1

# Esecuzione manuale remota
curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/script-name.sh | bash
```

**Vantaggi path locale:**
- ✅ Più veloce (no download)
- ✅ Funziona offline
- ✅ Stesso codice su tutti i server (git pull auto)

**Vantaggi GitHub raw (curl/wget):**
- ✅ Funziona ugualmente bene
- ✅ Sempre ultima versione GitHub
- ✅ Utile per host remoti o bootstrap

**⚠️ REGOLA IMPORTANTE: Modifiche al repository**
- ✅ Modifiche SOLO su VSCode locale (Windows)
- ✅ Commit e push da VSCode
- ✅ Git pull automatico distribuisce a tutti i server
- ❌ **MAI modificare file in `/opt/checkmk-tools/` sui server remoti**
- ❌ Modifiche locali vengono perse al prossimo git pull
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

**⚠️ REGOLA CRITICA - Gestione Password SSH:**
- ❌ **MAI inviare comandi multipli** quando SSH richiede password
- ✅ **ATTENDERE** che l'utente inserisca la password
- ✅ **UN COMANDO ALLA VOLTA** per host con autenticazione password
- ⚠️ Se vedi `password:` nell'output → FERMARSI e attendere conferma utente
- ✅ SSH session timeout dopo inattività → riconnettersi con comando singolo prima di operazioni multiple

**Host disponibili:**

```bash
# VPS CheckMK (chiave: ~/.ssh/checkmk + passphrase)
checkmk-vps-01    # monitor.nethlab.it (CheckMK 2.4.0p19.cre) - PRODUZIONE
                  # ⚠️ rclone configurato dentro il site OMD (non root)
                  # Path: /opt/omd/sites/monitoring/.config/rclone/rclone.conf
                  # Comandi: omd su monitoring -c "rclone ..."
checkmk-vps-02    # monitor01.nethlab.it - ⚠️ TEST CRITICI / STAGING

# Server locali CheckMK (autenticazione password)
checkmk-z1plus    # 192.168.10.128 (locale)
checkmk-testfrp   # 192.168.10.126 (user: admin_nethesis)

# Server locali altri (autenticazione password)
ns-lab00          # 192.168.10.100:2222 (root)
rl94ns8           # 10.155.100.70:22 (root, NethServer 8)
nsec8-stable      # 10.155.100.100:22 (root, NethServer Security 8)
                  # Agent CheckMK installato con: install-checkmk-agent-debtools-frp-nsec8c.sh
                  # Path: /opt/checkmk-tools/script-tools/full/install-checkmk-agent-debtools-frp-nsec8c.sh
laboratorio       # 10.155.100.1:2222 (root, NethSecurity 8)
                  # ROCKSOLID Mode validato - resistente major upgrade

# Altri server
fwlab             # 192.168.5.117:2222 (root)
redteam           # redteam.security.nethesis.it (root)
```

### 🚀 Workflow Accesso Remoto

**⚠️ IMPORTANTE - Ambiente Test:**
- **checkmk-vps-02** (monitor01.nethlab.it) è dedicato ai **TEST CRITICI**
- Usare **SEMPRE** vps-02 per testare:
  - Nuovi script di disaster recovery
  - Modifiche agli script di backup/restore
  - Upgrade CheckMK con cambiamenti critici
  - Test di procedure che potrebbero compromettere il sistema
- **NON testare direttamente su vps-01 (produzione)**

**1. Comando singolo SSH:**
```powershell
# Da PowerShell → esegui comando su VPS
wsl -- ssh checkmk-vps-01 "omd version"
wsl -- ssh checkmk-vps-02 "omd sites"
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
~/.ssh/config               # Configurazione SSH
~/.ssh/known_hosts          # Host verificati

# Windows paths originali (backup)
C:\Users\Marzio\.ssh\checkmk
```

---

## ☁️ Backup Cloud - rclone su CheckMK

**⚠️ IMPORTANTE - Configurazione rclone su checkmk-vps-01:**
- ✅ rclone è configurato **dentro il site OMD**, NON come utente root
- ✅ Path config: `/opt/omd/sites/monitoring/.config/rclone/rclone.conf`
- ✅ Remote configurato: `do-space-backup` (DigitalOcean Spaces)
- ✅ Bucket: `nethesis-checkmk-backups`

**Comandi corretti per accesso rclone:**
```bash
# ❌ SBAGLIATO (root non ha config)
ssh checkmk-vps-01 'rclone ls do-space-backup:nethesis-checkmk-backups/'

# ✅ CORRETTO (esegui come utente site)
ssh checkmk-vps-01 'omd su monitoring -c "rclone ls do-space-backup:nethesis-checkmk-backups/"'

# Lista ultimi backup
ssh checkmk-vps-01 'omd su monitoring -c "rclone ls do-space-backup:nethesis-checkmk-backups/ | tail -20"'

# Verifica spazio bucket
ssh checkmk-vps-01 'omd su monitoring -c "rclone size do-space-backup:nethesis-checkmk-backups/"'

# Download backup specifico
ssh checkmk-vps-01 'omd su monitoring -c "rclone copy do-space-backup:nethesis-checkmk-backups/backup-file.tar.gz /tmp/"'
```

**Script backup automatico:**
- Script: `/opt/checkmk-tools/script-tools/full/checkmk_rclone_space_dyn.sh`
- Eseguito da: site monitoring (non root)
- Cron: Configurato dentro il site OMD

---

---

**Ultimo aggiornamento**: 2026-01-27

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

8. **⚠️ CONTROLLO PROBLEMS OBBLIGATORIO**
   - ✅ **SEMPRE** controllare pannello PROBLEMS prima di considerare completato un task
   - ✅ Eseguire `get_errors()` dopo modifiche a file markdown/script
   - ✅ Priorità correzione errori:
     - **MD051** (link fragments invalidi) → Fix OBBLIGATORIO
     - **MD042** (empty links) → Rimuovere link o renderli validi
     - **MD022/MD031/MD032** (spacing) → Fix per qualità codice
     - **MD060** (table style) → Fix se facile, altrimenti ignorare
     - **MD024** (duplicate headings) → Valutare caso per caso
   - ⚠️ Se >50 errori: fixare batch con `multi_replace_string_in_file`
   - ✅ Confermare "0 errors" prima di dichiarare task completato
   - ❌ **NON** ignorare problemi senza consultare utente

9. **⚠️ TEST OBBLIGATORIO - TUTTI GLI SCRIPT MODIFICATI**
   - ❌ **MAI** dire "test completato" senza testare TUTTI gli script modificati
   - ✅ **SEMPRE** testare OGNI script modificato nella sessione corrente
   - ✅ Lista script modificati → test CIASCUNO separatamente
   - ⚠️ **CRITICO**: Se modifichi 3 script → testa tutti e 3, non solo 1!
   - ✅ Validare sintassi bash: `wsl bash -n script.sh`
   - ✅ Test esecuzione: eseguire su host remoto (nsec8-stable, laboratorio, etc.)
   - ✅ Verificare output/log per confermare funzionamento
   - ❌ Non dare per scontato che "se uno funziona, funzionano tutti"

**Esempio workflow test CORRETTO:**

```bash
# Modificati: install-script.sh, rocksolid-startup.sh, altro-script.sh

# OBBLIGATORIO: Testa TUTTI E 3 separatamente
wsl bash -n install-script.sh          # ✅ Validazione 1
wsl bash -n rocksolid-startup.sh       # ✅ Validazione 2
wsl bash -n altro-script.sh            # ✅ Validazione 3

# Test esecuzione TUTTI E 3 su host remoto
wsl -- ssh nsec8-stable "curl -fsSL .../install-script.sh | bash"      # ✅ Test 1
wsl -- ssh nsec8-stable "curl -fsSL .../rocksolid-startup.sh | bash"   # ✅ Test 2
wsl -- ssh nsec8-stable "curl -fsSL .../altro-script.sh | bash"        # ✅ Test 3

# SOLO ORA puoi dire "test completato"

```text

**Esempio workflow test SBAGLIATO:**

```bash
# Modificati: install-script.sh, rocksolid-startup.sh

# Test solo rocksolid
wsl -- ssh nsec8-stable "rocksolid-startup.sh"  # ✅ Test 1
# ❌ NON testato install-script.sh!

# ❌ ERRORE: Dici "test completato" senza testare install-script.sh

```text

**Esempio workflow corretto:**

```bash
# 1. Backup
cp file.txt file.txt.backup_2026-01-27_20-30-00

# 2. Chiedi conferma
"Ho creato backup in file.txt.backup_2026-01-27_20-30-00. Procedo con cancellazione?"

# 3. Solo dopo OK utente
rm file.txt

```text

11. **⚠️ MARKDOWN QUALITY - Prevenzione Errori Markdownlint**
   - ✅ **WORKFLOW OBBLIGATORIO per OGNI file .md creato/modificato:**
     1. **PRIMA**: Segui best practices markdownlint (vedi sotto)
     2. **SUBITO DOPO modifica**: Esegui `markdownlint file.md` (exit code 0=OK)
     3. **SE ERRORI**: Fix immediato e ri-esegui `markdownlint`
     4. **RIPETI**: Finché non ottieni exit code 0
     5. **OPZIONALE**: `get_errors()` per check VSCode (file path errors)
     6. **SOLO ALLORA**: Considera task completato
   - ✅ **Regole obbligatorie da rispettare:**
     - **Heading spacing**: Riga vuota SEMPRE dopo heading `###`

     - **List spacing**: Riga vuota dopo ultima voce lista prima di paragrafo/heading
     - **Code block spacing**: Riga vuota prima E dopo blocchi ` ``` `
     - **Code language**: Specificare SEMPRE linguaggio nei code block (bash, powershell, python, json, text)
     - **No empty links**: Mai usare link vuoti con anchor #, usare URL valido o rimuovere link
     - **Link fragments**: Se usi TOC con emoji negli heading, usa testo bold invece di link
   - ✅ **Esempi corretti:**
     - Heading con riga vuota sotto
     - Lista con riga vuota dopo ultima voce
     - Code block con linguaggio specificato (bash/powershell/json)
     - Code block con righe vuote prima e dopo
   - ❌ **Esempi SBAGLIATI:**
     - Heading senza riga vuota sotto
     - Lista senza riga vuota prima di paragrafo/heading
     - Code block senza linguaggio specificato
     - Code block senza righe vuote intorno
   - ✅ Dopo creazione/modifica file .md → `get_errors()` per validazione immediata
   - ✅ Preferire TOC senza link se heading hanno emoji (usa **testo bold** invece)

12. **Recupero script corrotti o persi**
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

```text

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

```text

**Host disponibili per test:**
- `nsec8-stable` (10.155.100.100) - NethSecurity 8 test environment
- `checkmk-vps-02` (monitor01.nethlab.it) - CheckMK staging/test
- `checkmk-z1plus` (192.168.10.128) - CheckMK locale test

10. **⚠️ WORKFLOW OBBLIGATORIO - Sviluppo e Test Script**
   - ✅ **SEMPRE seguire questo workflow completo** per modifiche a script bash/shell
   - ❌ **MAI** saltare step o dichiarare "completato" senza test reale
   - 🔄 **LOOP finché non funziona tutto** - non uscire fino a successo completo

**WORKFLOW OBBLIGATORIO (da seguire SEMPRE):**

```text

┌─────────────────────────────────────────────────────────┐
│ 1. MODIFICA/SCRITTURA SCRIPT                            │
│    - Implementa funzionalità richiesta                  │
│    - Segui best practices bash/PowerShell               │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ 2. TEST SINTASSI                                        │
│    Bash: wsl bash -n script.sh                          │
│    PowerShell: PSParser validation                      │
│    ✓ Exit code DEVE essere 0                            │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ 3. VERIFICA ESEGUIBILITÀ                                │
│    git ls-files -s script.sh                            │
│    ✓ DEVE mostrare 100755 (eseguibile)                  │
│    Se 100644 → git update-index --chmod=+x script.sh    │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ 4. ALLINEA REPO E COMMIT                                │
│    git add script.sh                                    │
│    git commit -m "descriptive message"                  │
│    git push                                             │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ 5. CHIEDI HOST PER TEST                                 │
│    "Su quale host vuoi testare?"                        │
│    Host disponibili: nsec8-stable, laboratorio, etc.    │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ 6. COLLEGATI WSL                                        │
│    wsl -- ssh <host>                                    │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ 7. TEST FUNZIONAMENTO COMPLETO                          │
│    - Esegui script da GitHub raw                        │
│    - Verifica output/log                                │
│    - Controlla exit code                                │
│    - Valida risultato atteso                            │
└─────────────────────────────────────────────────────────┘
                         ↓
              ┌──────────────────┐
              │ FUNZIONA TUTTO?  │
              └──────────────────┘
                    /    \
                   /      \
              NO ↙        ↘ SI
                /          \
    ┌──────────────┐    ┌──────────────────────┐
    │ TORNA A 1.   │    │ ✅ ESCI DAL LOOP     │
    │ FIX + RITEST │    │ Task completato!     │
    └──────────────┘    └──────────────────────┘

```text

**⚠️ REGOLE CRITICHE:**
- ❌ **MAI** dire "test completato" senza test REALE su host remoto
- ❌ **MAI** uscire dal loop se ci sono errori
- ✅ **SEMPRE** fixare errori e ri-testare automaticamente
- ✅ **SEMPRE** testare TUTTI gli script modificati nella sessione
- 🔄 **LOOP infinito** finché non funziona o utente ferma

**Esempio completo:**

```bash
# 1. Modifica
vi install-script.sh

# 2. Test sintassi
wsl bash -n install-script.sh  # Exit: 0 ✓

# 3. Verifica eseguibilità
git ls-files -s install-script.sh  # 100755 ✓

# 4. Commit
git add install-script.sh
git commit -m "fix: correzione download dinamico"
git push

# 5. Chiedi host
"Su quale host testo? [nsec8-stable]"

# 6. Collegati
wsl -- ssh nsec8-stable

# 7. Test
curl -fsSL .../install-script.sh | bash
# Output: ERRORE linea 45

# ❌ ERRORE → TORNA A 1 (fix + ritest)
# Fix errore linea 45, ricommit, ritest...

# ✅ OK → Test completato, ESCI DAL LOOP

```text

11. **Script eseguibili - Verifica SEMPRE permessi Git**
   - ⚠️ **Windows (NTFS) NON preserva il bit eseguibile Unix**
   - ✅ **SEMPRE** quando crei/modifichi script bash/shell (.sh):
     1. Crea/modifica il file
     2. Verifica permessi: `git ls-files -s script.sh`
     3. Se mostra `100644` (NON eseguibile) → FIX:
        ```bash
        git update-index --chmod=+x script.sh
        ```

     4. Verifica: `git ls-files -s script.sh` → deve mostrare `100755`
     5. Committo e push normalmente
   - ✅ **Controllo batch** su directory:
     ```bash
     # Trova script NON eseguibili
     git ls-files -s script-tools/full/*.sh | Select-String "100644"

     # Rendi tutti eseguibili
     git update-index --chmod=+x script-tools/full/*.sh
     ```

   - ⚠️ **NON fare affidamento** su `wsl -- test -x` su Windows → usa `git ls-files -s`
   - ✅ Quando proponi nuovi script bash → renderli subito eseguibili con git update-index

**Esempio workflow creazione script:**

```powershell
# 1. Crea script
New-Item script-tools/full/nuovo-script.sh

# 2. Scrivi contenuto
# ... edit file ...

# 3. OBBLIGATORIO: Rendi eseguibile
git add script-tools/full/nuovo-script.sh
git update-index --chmod=+x script-tools/full/nuovo-script.sh

# 4. Verifica (deve mostrare 100755)
git ls-files -s script-tools/full/nuovo-script.sh

# 5. Commit
git commit -m "feat: nuovo script"

```text

---
## 📋 NethSecurity 8 - Local Checks CheckMK

### ⚠️ REGOLA DEPLOYMENT - Mantenere estensione .sh

**Local checks devono mantenere l'estensione `.sh` anche quando deployed:**

```bash
# ✅ CORRETTO - Mantieni estensione
cp /opt/checkmk-tools/script-check-nsec8/full/check_vpn_tunnels.sh \
   /usr/lib/check_mk_agent/local/check_vpn_tunnels.sh
#                                                    ^^^ CON .sh

# ❌ SBAGLIATO - Non rimuovere estensione
cp script.sh /usr/lib/check_mk_agent/local/script  # NO!

```text

**Motivo preferenza utente:**
- Coerenza con repository (tutti gli script .sh)
- Più facile identificare tipo file
- CheckMK esegue comunque file con estensione

**Auto-restore deve usare nome completo con estensione:**

```bash
# In rocksolid-startup-check.sh
basename_script=$(basename "$script")  # NON rimuovere .sh
cp "$script" "/usr/lib/check_mk_agent/local/$basename_script"

```text

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

```text

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

```text

3. **Via template custom** (avanzato)

```bash
# Crea template custom in /etc/e-smith/templates-custom/
# Le modifiche sopravvivono ai signal-event

```text

**⚠️ Conseguenze modifiche manuali:**
- `signal-event nethserver-<servizio>-save` → configurazione ripristinata
- Riavvio servizio → configurazione ripristinata
- Aggiornamenti sistema → configurazione ripristinata

**✅ SEMPRE chiedere conferma utente** prima di suggerire modifiche manuali a file su NethServer!

---

## 🔧 NethSecurity 8 - NGINX Web UI Major Upgrade Issue

### ⚠️ PROBLEMA CRITICO - Symlink /etc/nginx/uci.conf cancellato durante upgrade

**Sintomo:**
- Post major upgrade: nginx non parte, Web UI (porta 9090) non disponibile
- Log error: `open() "/etc/nginx/nginx.conf" failed (2: No such file or directory)`
- Directory `/etc/nginx/` esiste e protetta, ma manca symlink

**Causa ROOT:**
- NethSecurity usa `/var/lib/nginx/uci.conf` come configurazione nginx principale
- `/etc/nginx/uci.conf` è un **symlink** → `/var/lib/nginx/uci.conf`
- Durante major upgrade: symlink cancellato anche se `/etc/nginx/` è protetto in sysupgrade.conf
- Nginx cerca `uci.conf` ma non lo trova → fallisce avvio

**Soluzione implementata (commit 6107753 + 1986623):**

1. **Protezione directory** (`install-checkmk-agent-persistent-nsec8.sh`):

```bash
# In protect_checkmk_installation()
add_to_sysupgrade "/etc/nginx/" "NGINX configuration (Web UI NethSecurity)"

```text

2. **Ripristino automatico symlink** (`rocksolid-startup-check.sh`):

```bash
# Prima di verificare nginx
if [ ! -L /etc/nginx/uci.conf ] && [ -f /var/lib/nginx/uci.conf ]; then
    log "[Nginx] Ripristino symlink uci.conf..."
    ln -sf /var/lib/nginx/uci.conf /etc/nginx/uci.conf 2>/dev/null || true
fi

```text

**Fix manuale emergenza:**

```bash
# Su sistema già upgradato con nginx rotto
ln -sf /var/lib/nginx/uci.conf /etc/nginx/uci.conf
/etc/init.d/nginx restart
# Web UI torna disponibile su porta 9090

```text

**Verifica soluzione:**

```bash
# Dopo upgrade/reboot
ls -la /etc/nginx/uci.conf  # Deve essere symlink
/etc/init.d/nginx status    # Deve essere "running"
netstat -tlnp | grep :9090  # Deve mostrare nginx in ascolto

```text

**Note tecniche:**
- `/var/lib/nginx/uci.conf` generato dinamicamente da nginx-ssl-util
- Contiene configurazioni server blocks per porte 80/443/9090
- Symlink necessario perché nginx include `/etc/nginx/uci.conf` nel main config
- Backup laboratorio disponibile: `C:\Users\Marzio\Desktop\CheckMK\nginx-backup-laboratorio.tar.gz`

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

```text

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

```text

checkmk-tools/
├── script-check-ns7/full/         # Script NethServer 7
├── script-check-ns8/full/         # Script NethServer 8
├── script-check-proxmox/full/     # Script Proxmox
├── script-check-ubuntu/full/      # Script Ubuntu
├── script-tools/full/             # Tools vari
├── script-notify-checkmk/full/    # Notifiche CheckMK
└── Ydea-Toolkit/full/             # Integrazione Ydea

```text

**Output Esempio:**

```text

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

```text

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

```text

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

```text

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

```text

**Esempi esecuzione da GitHub (fallback o host remoti):**

```bash
# Cron job - esecuzione diretta da GitHub
0 3 * * * curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/cleanup-checkmk-retention.sh | bash >> /var/log/script.log 2>&1

# Esecuzione manuale remota
curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/script-name.sh | bash

```text

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

```text

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

```text

---

## 🔌 Accesso Remoto SSH - VPS e Server Locali

### Setup WSL SSH

**Environment configurato:**
- ✅ WSL: Ubuntu su Windows (`wsl -- bash -c "command"`)
- ✅ SSH Keys: `~/.ssh/checkmk` (protetta da passphrase)
- ✅ SSH Config: `~/.ssh/config` con alias host
- ✅ SSH ControlMaster: Riutilizzo connessioni (passphrase 1 volta, poi 1 min attiva)

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
nodo-proxmox      # 10.155.100.20:22 (root, Proxmox VE)
ns-lab00          # 192.168.10.100:2222 (root)
box-lab00         # 192.168.10.132:22 (root) - Host share \\192.168.10.132\usbshare
rl94ns8           # 10.155.100.40:22 (root, NethServer 8)
                  # Moduli: samba1, mail2, webtop1, webtop3
                  # Nodo completo per test report quindicinale NS8 (AD + Mail + WebTop)
rl94ns81          # 10.155.100.41:22 (root, NethServer 8)
                  # Moduli: webtop1 (con Postgres attivo)
                  # Nodo WebTop per test condivisioni email
nsec8-stable      # 10.155.100.100:22 (root, NethServer Security 8)
                  # Agent CheckMK installato con: install-checkmk-agent-debtools-frp-nsec8c.sh
                  # Path: /opt/checkmk-tools/script-tools/full/install-checkmk-agent-debtools-frp-nsec8c.sh
laboratorio       # 10.155.100.1:2222 (root, NethSecurity 8)
                  # ROCKSOLID Mode validato - resistente major upgrade

# Altri server
fwlab             # 192.168.5.117:2222 (root)
redteam           # redteam.security.nethesis.it (root)

```text

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

```text

**2. Esecuzione script da GitHub:**

```powershell
# Download ed esecuzione diretta script dal repository
wsl -- ssh checkmk-vps-01 "curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/cleanup-checkmk-retention.sh | bash"

# Con parametri
wsl -- ssh checkmk-vps-01 "curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/script.sh | bash -s -- arg1 arg2"

```text

**3. Verifica stato CheckMK remoto:**

```powershell
# Check rapido su tutti i VPS
wsl -- ssh checkmk-vps-01 "omd status"
wsl -- ssh checkmk-vps-02 "omd status"

# Verifica backup
wsl -- ssh checkmk-vps-01 "ls -lh /opt/omd/sites/monitoring/var/check_mk/notify-backup/"

```text

**4. Deploy script su VPS:**

```powershell
# NON copiare file, eseguire sempre da GitHub!
# ❌ SBAGLIATO: scp script.sh checkmk-vps-01:/usr/local/bin/
# ✅ CORRETTO: esegui da GitHub con curl

wsl -- ssh checkmk-vps-01 "curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/cleanup-checkmk-retention.sh | bash"

```text

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

```text

**Verifica logs:**

```powershell
wsl -- ssh checkmk-vps-01 "tail -100 /omd/sites/monitoring/var/log/notify.log"

```text

**Raccolta info sistema:**

```powershell
wsl -- ssh checkmk-vps-01 "df -h && free -h && uptime"

```text

### ⚙️ Path Chiavi e Config

```bash
# WSL paths
~/.ssh/checkmk              # Chiave privata VPS (con passphrase)
~/.ssh/config               # Configurazione SSH
~/.ssh/known_hosts          # Host verificati

# Windows paths originali (backup)
C:\Users\Marzio\.ssh\checkmk

```text

---

## ☁️ Backup Cloud - rclone su CheckMK

**⚠️ IMPORTANTE - Configurazione rclone su checkmk-vps-01:**
- ✅ rclone è configurato **dentro il site OMD**, NON come utente root
- ✅ Path config: `/opt/omd/sites/monitoring/.config/rclone/rclone.conf`
- ✅ Remote configurato: `do` (DigitalOcean Spaces)
- ✅ Bucket: `testmonbck`
- ✅ Struttura: `checkmk-backups/job00-daily/`, `checkmk-backups/job01-weekly/`, `checkmk-backups/monitoring-minimal/`

**Comandi corretti per accesso rclone:**

```bash
# ❌ SBAGLIATO (comando errato)
ssh checkmk-vps-01 'rclone ls do:testmonbck'
ssh checkmk-vps-01 'omd su monitoring -c "rclone ..."'

# ✅ CORRETTO (su - monitoring -c)
ssh checkmk-vps-01 'su - monitoring -c "rclone ls do:testmonbck"'

# Lista ultimi backup
ssh checkmk-vps-01 'su - monitoring -c "rclone ls do:testmonbck"' | tail -20

# Lista cartella specifica
ssh checkmk-vps-01 'su - monitoring -c "rclone ls do:testmonbck/checkmk-backups/job00-daily/"'

# Verifica spazio bucket
ssh checkmk-vps-01 'su - monitoring -c "rclone size do:testmonbck"'

# Download backup specifico
ssh checkmk-vps-01 'su - monitoring -c "rclone copy do:testmonbck/checkmk-backups/job00-daily/file.tar.gz /tmp/"'

```text

**Backup disponibili:**
- **job00-daily**: Backup daily completi (~1.2 MB)
- **job01-weekly**: Backup weekly completi con history (~378 MB)
- **monitoring-minimal**: Backup ultra-minimali (~115 KB)

**Script backup automatico:**
- Script: `/opt/checkmk-tools/script-tools/full/checkmk_rclone_space_dyn.sh`
- Eseguito da: site monitoring (non root)
- Cron: Configurato dentro il site OMD

---

## 🚨 INCIDENTI E TROUBLESHOOTING

### 30 Gennaio 2026 - Update Windows + VSCode Crash

**PROBLEMA INIZIALE:**
- Aggiornamento Microsoft Windows ha causato errori all'avvio di VSCode
- Errore principale: `EPIPE: broken pipe, write` su processi interni
- Stack trace mostra crash in `console.value`, `Writable.write`, socket communication

**COSA È STATO FATTO (E PEGGIORATO):**
1. ❌ Tentato reset cache VSCode
2. ❌ Tentato riavvio multipli
3. ❌ **Modificata modalità login in "basic" - QUESTO HA ROTTO TUTTO**
4. ❌ Modifiche a configurazioni interne
5. ⚠️ Update Windows rimosso (TARDI)
6. ❌ Situazione peggiorata invece di migliorare
7. ❌ **Uninstall approfondito con Revo Uninstaller + Reinstall VSCode** - NON ha risolto
8. ❌ Reset cache post-reinstall - NON ha risolto
9. ❌ Riabilitato github.gitAuthentication - NON ha risolto
10. ❌ Restart Windows Explorer - NON ha risolto
11. ❌ Ricreato chiavi registro VSCode (Applications\Code.exe, DefaultIcon) - NON ha risolto

**STATO ATTUALE (30/01/2026 ore ~19:00):**
- VSCode non si avvia o non mostra nulla
- Ultimo danno non risolto
- Necessario ripristino completo
- ⚠️ **PATTERN CRITICO**:
  - Start-Process da PowerShell → VSCode SI AVVIA
  - Click su Code.exe con mouse → NON SI AVVIA
  - Click su collegamento menu Start → NON SI AVVIA
  - Comando `code .` da terminale → SI AVVIA
  - Qualunque azione MANUALE utente → FALLISCE
  - Qualunque azione via COMANDO → FUNZIONA
- ✅ **Problema SPECIFICO di VSCode** - altri exe (notepad, ecc.) funzionano normalmente con doppio click
- ❌ **NON è problema generale Windows** - circoscritto solo a Code.exe

**SOLUZIONE TROVATA (30/01/2026 ore ~19:15):**
- ✅ VSCode si avvia correttamente con:
  ```powershell
  cd C:\Users\Marzio\Desktop\CheckMK\checkmk-tools
  code .
  ```

- ⚠️ Importante fare `cd` nella directory workspace PRIMA di lanciare `code .`
- ⚠️ Non lanciare `code` senza parametri o da directory diversa
- ❌ **Collegamento desktop/start menu NON funziona** - lanciare sempre da terminale
- ❌ **NESSUNA SOLUZIONE TROVATA** per ripristinare funzionamento normale
- ⚠️ Problema causato da Revo Uninstaller che ha cancellato chiavi registro critiche
- ⚠️ Ricreare chiavi registro NON ha risolto - problema più profondo
- ✅ **WORKAROUND TEMPORANEO**: Aprire PowerShell e usare `code .`

**CAUSA ROOT (30/01/2026 ore ~19:45):**

- 🔍 Diagnostica con `Code.exe --verbose` rivela:

  ```text
  Sending some foreground love to the running instance: 17752
  Sent env to running instance. Terminating...
  ```

- ⚠️ **VSCode si connette a istanza zombie nascosta/corrotta** invece di aprire nuova finestra
- Quando lanciato dal collegamento, VSCode rileva istanza esistente (PID 17752) e le invia il comando
- Ma quella finestra è nascosta o corrotta dall'update Windows
- `code .` con workspace funziona perché forza apertura in quel contesto specifico
- Soluzione: killare TUTTI i processi VSCode prima di riaprire dal collegamento

**CAUSA ROOT (30/01/2026 ore ~19:45):**

- 🔍 Diagnostica con `Code.exe --verbose` rivela:

  ```text
  Sending some foreground love to the running instance: 17752
  Sent env to running instance. Terminating...
  ```

- ⚠️ **Problema reale: VSCode aperto come ADMINISTRATOR**
- Windows impedisce apertura multiple istanze Administrator di VSCode
- Tentativo di aprire da collegamento/menu Start → errore "Another instance of Code is already running as administrator"
- `code .` da terminale integrato funziona perché usa stessa istanza admin già aperta
- L'update Windows potrebbe aver forzato VSCode a girare sempre come admin
- **Soluzione da testare**: Chiudere VSCode admin, riaprire senza privilegi elevati

**✅ SOLUZIONE DEFINITIVA (30/01/2026 ore ~22:30) - PROBLEMA RISOLTO:**

**Causa ROOT reale:**

- ⚠️ **Variabile d'ambiente `ELECTRON_RUN_AS_NODE` presente nel sistema**

- ⚠️ **Variabile d'ambiente `ELECTRON_RUN_AS_NODE` presente nel sistema**
- Questa variabile (anche se impostata a "0") causa malfunzionamento di Electron/VSCode
- L'update Windows potrebbe averla introdotta o riattivata
- Sintomi: VSCode si avvia da CLI ma NON da GUI (doppio click/menu Start)

**Fix definitivo (persistente):**

**1. Verifica variabile in cmd.exe:**

```cmd
set ELECTRON_RUN_AS_NODE

```text

Se mostra qualcosa tipo `ELECTRON_RUN_AS_NODE=0` o altro valore → **va rimossa completamente**

**2A. Rimozione via GUI (consigliato):**

```text

1. Win + R → esegui: SystemPropertiesAdvanced
2. Tab "Avanzate" → pulsante "Variabili d'ambiente..."
3. Cerca ELECTRON_RUN_AS_NODE in:
   - "Variabili utente" (sezione superiore)
   - "Variabili di sistema" (sezione inferiore)
4. Se presente → Seleziona → pulsante "Elimina"
5. OK su tutte le finestre
6. Logout/Login Windows (o riavvio)

```text

**2B. Rimozione via CLI (rapido):**

```cmd
# Apri cmd.exe come Amministratore ed esegui:
reg delete "HKCU\Environment" /v ELECTRON_RUN_AS_NODE /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v ELECTRON_RUN_AS_NODE /f

```text

Poi **logout/login** (o riavvio) Windows.

**3. Verifica dopo logout/login:**

```cmd
set ELECTRON_RUN_AS_NODE

```text

Deve mostrare:

```text

Environment variable ELECTRON_RUN_AS_NODE not defined

```text

**4. Verifica finale VSCode:**

```cmd
"C:\Program Files\Microsoft VS Code\Code.exe" --version
"C:\Program Files\Microsoft VS Code\Code.exe" --disable-extensions

```text

Atteso:
- `--version` **NON deve mostrare** output strano tipo "v22.x.x"
- `--disable-extensions` avvia VSCode correttamente
- Log "Extension host ... exited with code: 0" è normale con estensioni disabilitate

**5. Avvio normale:**

```cmd
"C:\Program Files\Microsoft VS Code\Code.exe"

```text

✅ Doppio click su Code.exe, collegamento menu Start, tutto **funziona correttamente**

**6. Note reinstallazione VSCode (se necessaria):**
- ✅ Usare sempre: **System Installer x64** → `VSCodeSetup-x64-<versione>.exe`
- ❌ Evitare: `VSCodeUserSetup-...` (User Installer), soprattutto dopo feature update Windows

**7. Recupero settings (opzionale):**
Se avevi rinominato `%APPDATA%\Code` (es. `Code.old`):

```powershell
# Chiudi VSCode completamente
# Rinomina per test:
Rename-Item "$env:APPDATA\Code" "$env:APPDATA\Code.new"
Rename-Item "$env:APPDATA\Code.old" "$env:APPDATA\Code"
# Avvia VSCode
# Se problemi ritornano, rollback:
# Rename-Item "$env:APPDATA\Code" "$env:APPDATA\Code.problem"
# Rename-Item "$env:APPDATA\Code.new" "$env:APPDATA\Code"

```text

**⚠️ CHECKPOINT CRITICO:**
- **Variabile ELECTRON_RUN_AS_NODE = poison** per VSCode/Electron
- Sempre verificare con `set ELECTRON_RUN_AS_NODE` in caso di problemi VSCode
- Rimuoverla COMPLETAMENTE (non basta impostarla a "0")
- Logout/login Windows **obbligatorio** dopo rimozione

**LEZIONI APPRESE:**
- ⚠️ Errori `EPIPE: broken pipe` sono **transitori** - NON richiedono riavvio
- ⚠️ Stack trace con path `Microsoft%20VS%20Code/resources.../` indicano problemi **interni VSCode**
- ✅ Prima azione: **rimuovere update Windows SUBITO** (non dopo vari tentativi)
- ✅ Seconda azione: **reset cache minimale** (non modifiche aggressive)
- ❌ **MAI** modificare configurazioni interne senza backup completo
- ✅ Creare **System Restore Point PRIMA** di troubleshooting aggressivo

**PROCEDURE DI RIPRISTINO EMERGENZA VSCode:**

**Step 1 - Reset cache leggero (SEMPRE provare prima):**

```powershell
# Chiudi VSCode
taskkill /F /IM Code.exe

# Cancella solo cache volatile
Remove-Item -Recurse -Force "$env:APPDATA\Code\Cache\*" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:APPDATA\Code\CachedData\*" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:APPDATA\Code\logs\*" -ErrorAction SilentlyContinue

# Riavvia
code

```text

**Step 2 - Reset estensioni (se Step 1 fallisce):**

```powershell
# Backup lista estensioni
code --list-extensions > "$env:USERPROFILE\Desktop\vscode-extensions-backup.txt"

# Disabilita tutte le estensioni
code --disable-extensions

```text

**Step 3 - Reinstallazione pulita (ultimo resort):**

```powershell
# Backup configurazioni utente
Copy-Item -Recurse "$env:APPDATA\Code\User" "$env:USERPROFILE\Desktop\VSCode-User-Backup"

# Disinstalla VSCode (mantieni dati utente)
# Reinstalla versione stabile da https://code.visualstudio.com/

# Ripristina configurazioni
Copy-Item -Recurse "$env:USERPROFILE\Desktop\VSCode-User-Backup\*" "$env:APPDATA\Code\User"

```text

**⚠️ REGOLA CRITICA PER FUTURO:**
- Errori `EPIPE`, `broken pipe`, socket errors = **IGNORARE E CONTINUARE**
- Non sono critici, sono comunicazioni IPC interne che si ripristinano da sole
- Riavvio VSCode window (Ctrl+R) sufficiente se proprio necessario
- **NON FARE** troubleshooting aggressivo per errori transitori

**BACKUP PATH CRITICI:**
- Settings: `$env:APPDATA\Code\User\settings.json`
- Keybindings: `$env:APPDATA\Code\User\keybindings.json`
- Extensions list: `code --list-extensions`
- Workspace: `.vscode/` dentro ogni progetto

---

## 🚀 CHECKPOINT - Sistema ROCKSOLID NethSecurity 8

### ⚠️ STATO ATTUALE (2026-02-10): SISTEMA DISMESSO

**ATTENZIONE:**
- ❌ **Sistema ROCKSOLID rimosso da nsec8-stable e laboratorio** (10 febbraio 2026)
- ❌ **NON eseguire install-checkmk-agent-persistent-nsec8.sh** su nsec8-stable (10.155.100.100) e laboratorio (10.155.100.1)
- ✅ CheckMK Agent e FRP rimangono attivi e funzionanti
- ✅ Repository /opt/checkmk-tools ancora presente (auto-sync git funzionante)
- ❌ Rimossi: /opt/checkmk-backups/, /etc/checkmk-post-upgrade.sh, autocheck rc.local, protezioni sysupgrade.conf

**Componenti rimosse:**
- Backup binari critici (/opt/checkmk-backups/binaries/)
- Script post-upgrade (/etc/checkmk-post-upgrade.sh)
- Autocheck all'avvio (rocksolid-startup-check.sh)
- Protezioni sysupgrade.conf (CheckMK, FRP, QEMU-GA entries)
- Marker FRP (/etc/.frp-installed)

**Componenti mantenuti:**
- CheckMK Agent (porta 6556) - funzionante
- FRP Client + configurazione tunnel
- QEMU Guest Agent
- Repository /opt/checkmk-tools + auto-sync git (cron ogni minuto)

---

### ✅ Implementazione Completata (2026-02-04) - STORICO

**Obiettivo raggiunto:**
- ✅ Eliminazione di TUTTI gli URL statici/hardcoded dagli script di installazione
- ✅ Download dinamico dei pacchetti da repository OpenWrt/NethSecurity
- ✅ Sistema auto-riparante post major-upgrade
- ✅ Validazione completa su host production

**Script validati e production-ready:**

1. **install-checkmk-agent-persistent-nsec8.sh** (commit b29a2cf)
   - Path: `script-tools/full/install-checkmk-agent-persistent-nsec8.sh`
   - Funzione: Installazione completa CheckMK Agent + FRP Client + QEMU-GA + Auto Git Sync
   - Fix implementati:
     - ✅ Dynamic package download via `download_openwrt_package()`
     - ✅ Pattern fix: `grep "${package_name}_"` (corregge rilevamento pacchetti)
     - ✅ Dependencies chain: libbfd → ar → objdump → binutils con `--force-depends`
     - ✅ Gestione corruzione binari (ar corrotto durante upgrade)
   - Test: ✅ nsec8-stable, ✅ laboratorio (da GitHub)

2. **rocksolid-startup-check.sh** (commit ea67364)
   - Path: `script-tools/full/rocksolid-startup-check.sh`
   - Funzione: Verifica e auto-remediation all'avvio sistema
   - Fix implementati:
     - ✅ Logic reordering: backup restore → corruption check → dependencies install
     - ✅ Git auto-install: download git + git-http da OpenWrt se mancante
     - ✅ Pattern fix identico a install script
     - ✅ Verifica DOPO ripristino backup (non prima)
   - Test: ✅ nsec8-stable, ✅ laboratorio (da GitHub)

**Host validati (production):**

| Host | IP | OS | Status | Packages |
|------|----|----|--------|----------|
| **nsec8-stable** | 10.155.100.100:22 | NethSecurity 8.7.1 | ✅ ROCKSOLID | ar 2.40-1, git 2.43.2-1, libbfd 2.40-1 |
| **laboratorio** | 10.155.100.1:2222 | NethSecurity 8.7.1 | ✅ ROCKSOLID | ar 2.40-1, git 2.43.2-1, libbfd 2.40-1 |

**Componenti attivi:**
- ✅ CheckMK Agent 2.4.0p20 (porta 6556)
- ✅ FRP Client (tunnel verso monitor.nethlab.it:7000)
- ✅ Auto Git Sync (cron ogni minuto, /opt/checkmk-tools)
- ✅ Rocksolid startup check (rc.local, log: /var/log/rocksolid-startup.log)
- ✅ 12 local checks deployed

**Protezioni major upgrade:**
- ✅ File critici in `/etc/sysupgrade.conf`
- ✅ Binari backuppati in `/opt/checkmk-backups/binaries/`
- ✅ Nginx configuration (`/etc/nginx/`) protetta
- ✅ Script auto-ripristino: `/etc/checkmk-post-upgrade.sh`

### 🔧 Dettagli Tecnici

**Dynamic Package Download:**

```bash
download_openwrt_package() {
    local package_name="$1"
    local repo_url="$2"
    local output_path="$3"

    # Download Packages.gz index
    wget -q -O /tmp/Packages.gz "$repo_url/Packages.gz"

    # Parse package filename (fix: grep "${package_name}_" non "/$package_name")
    local package_file=$(gunzip -c /tmp/Packages.gz | grep "^Filename:" | grep "${package_name}_" | head -1 | awk '{print $2}')

    # Download package
    wget -q -O "$output_path" "$repo_url/$package_file"
}

```text

**Dependencies Chain (circular dependency fix):**

```bash
# Order matters: libbfd first (shared library), then ar (uses libbfd)
opkg install --force-depends /tmp/libbfd.ipk
opkg install --force-depends /tmp/ar.ipk
opkg install --force-depends /tmp/objdump.ipk
opkg install --force-depends /tmp/binutils.ipk

```text

**Rocksolid Logic (fixed order):**

```bash
# STEP 1: Restore backups FIRST
for backup in /opt/checkmk-backups/binaries/*.backup; do
    cp -p "$backup" "$dest" 2>/dev/null || true
done

# STEP 2: Check corruption AFTER restore (not before!)
if [ -x /usr/bin/ar ]; then
    if ! /usr/bin/ar --version >/dev/null 2>&1; then
        BINARIES_CORRUPTED=1
    fi
fi

# STEP 3: Install dependencies if still corrupted
if [ $BINARIES_CORRUPTED -eq 1 ]; then
    download_openwrt_package "libbfd" "$REPO_BASE" "/tmp/libbfd.ipk"
    opkg install --force-depends /tmp/libbfd.ipk
    download_openwrt_package "ar" "$REPO_BASE" "/tmp/ar.ipk"
    opkg install --force-depends /tmp/ar.ipk
fi

```text

### 📋 Testing Workflow Validato

**Workflow obbligatorio seguito:**
1. ✅ Modifica script (dynamic download, pattern fix, logic reorder, git auto-install)
2. ✅ Test sintassi: `wsl bash -n script.sh` (exit code 0)
3. ✅ Verifica eseguibilità: `git ls-files -s` (100755)
4. ✅ Commit + push: b29a2cf, ea67364, 68661c1, 67f3cbc
5. ✅ Test su nsec8-stable: `curl -fsSL https://raw.githubusercontent.com/.../script.sh | bash`
6. ✅ Test su laboratorio: `curl -fsSL https://raw.githubusercontent.com/.../script.sh | bash`
7. ✅ Validazione output: ar/git/libbfd versioni corrette installate

**Test reali eseguiti:**
- ✅ Post major upgrade scenario (ar corrotto, git mancante)
- ✅ Fresh install su sistema pulito
- ✅ Re-install su sistema già configurato (idempotenza)
- ✅ Esecuzione da GitHub (non repo locale)

### 🎯 Lessons Learned

**Pattern Matching:**
- ❌ `grep "/$package_name"` → Non trova "package_name_version.ipk"
- ✅ `grep "${package_name}_"` → Corretto per formato Packages.gz

**Circular Dependencies:**
- ❌ `opkg install binutils` → "cannot find dependency ar"
- ✅ Install chain: libbfd → ar → objdump → binutils con `--force-depends`

**Backup Restore Timing:**
- ❌ Check corruption BEFORE backup restore → Binari mancanti post-upgrade mai rilevati
- ✅ Restore backups FIRST, THEN check corruption → Rileva problemi anche se binario presente ma corrotto

**Testing:**
- ❌ Test solo 1 script di 3 modificati → Script non testati falliscono in production
- ✅ Test TUTTI gli script modificati nella sessione → 100% coverage
- ❌ Test da repo locale → Potrebbe essere stale
- ✅ Test da GitHub raw URL → Garantisce production source

**Git Auto-Install:**
- ⚠️ Git può essere rimosso durante major upgrade
- ✅ Auto-sync repository richiede git funzionante
- ✅ Rocksolid deve auto-installare git se mancante
- ✅ Necessari: git + git-http (dipendenza)

### 🚀 Sistema Production-Ready

**Status finale:**
- ✅ Entrambi gli host (nsec8-stable, laboratorio) ROCKSOLID mode attivo
- ✅ Tutti i binari critici protetti e auto-riparabili
- ✅ CheckMK Agent, FRP Client, QEMU-GA operativi
- ✅ Auto Git Sync funzionante (repository aggiornato ogni minuto)
- ✅ Sistema resiliente a major upgrade NethSecurity/OpenWrt
- ✅ Zero hardcoded URLs - tutto dinamico da repository upstream

**Prossimi major upgrade:**
- Sistema auto-ripristina binari corrotti (ar, tar, gzip, libbfd)
- Sistema auto-installa git se rimosso
- Sistema verifica e riavvia servizi critici (CheckMK, FRP)
- Log dettagliato in `/var/log/rocksolid-startup.log`
- **Zero intervento manuale richiesto**

---

**Ultimo aggiornamento**: 2026-02-04

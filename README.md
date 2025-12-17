# 🛡️ CheckMK Tools Collection

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CheckMK](https://img.shields.io/badge/CheckMK-Compatible-green.svg)](https://checkmk.com/)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Bash](https://img.shields.io/badge/Bash-4.0+-green.svg)](https://www.gnu.org/software/bash/)

Collezione completa di script per il monitoraggio e la gestione di infrastrutture con CheckMK. Include script di check per diverse piattaforme, sistemi di notifica personalizzati, e tool di deployment automatizzato.

---

## 📋 Indice

- [Caratteristiche Principali](#-caratteristiche-principali)
- [Struttura Repository](#-struttura-repository)
- [Script di Check](#-script-di-check)
  - [Windows](#windows)
  - [NethServer 7](#nethserver-7)
  - [NethServer 8](#nethserver-8)
  - [Ubuntu/Linux](#ubuntulinux)
  - [Proxmox](#proxmox)
- [Script di Notifica](#-script-di-notifica)
- [Tool di Deploy](#-tool-di-deploy)
- [Automazione e Backup](#-automazione-e-backup)
- [Installazione](#-installazione)
- [Documentazione](#-documentazione)
- [Contributi](#-contributi)

---

## 🎯 Caratteristiche Principali

### ✨ Multi-Piattaforma
- **Windows**: PowerShell scripts per Windows Server (AD, IIS, Ransomware Detection)
- **Linux**: Bash scripts per NethServer, Ubuntu, Proxmox
- **Container**: Monitoraggio Podman/Docker su NethServer 8

### 🔄 Auto-Update Pattern
- **Remote Wrappers**: Script che si auto-aggiornano da GitHub
- **Cache Intelligente**: Sistema di caching con timeout configurabile (60s default)
- **Fallback Resiliente**: Usa cache obsoleta se GitHub non raggiungibile

### 🚀 Deploy Automatizzato
- **Smart Deploy**: Sistema ibrido per deployment multi-host
- **Backup Automatico**: Snapshot pre-deployment con rollback
- **Validazione**: Test sintassi e funzionalità pre-deployment
- **Interactive Menu**: Deploy interattivo con selezione script per OS

### 📧 Notifiche Avanzate
- **Email Real IP**: Notifiche con IP reale anche dietro proxy FRP
- **Telegram Integration**: Notifiche Telegram con detection automatica scenario
- **HTML + Grafici**: Email HTML con grafici performance inclusi

---

## 📁 Struttura Repository

```
checkmk-tools/
├── script-check-windows/          # Script check per Windows
│   ├── nopolling/
│   │   └── ransomware_detection/  # ⭐ Rilevamento ransomware real-time
│   └── polling/
│
├── script-check-ns7/              # Script check per NethServer 7
│   ├── nopolling/                 # Check senza polling (eventi, sessioni)
│   └── polling/                   # Check con polling (metriche)
│
├── script-check-ns8/              # Script check per NethServer 8
│   ├── nopolling/                 # Podman events, SOS monitor
│   └── polling/
│
├── script-check-ubuntu/           # Script check per Ubuntu/Linux
│   ├── nopolling/
│   └── polling/
│
├── Proxmox/                       # Script check per Proxmox VE
│   ├── nopolling/                 # VM status, snapshot status, disks
│   └── polling/
│
├── script-notify-checkmk/         # Script notifica personalizzati
│   ├── mail_realip*               # Email con IP reale + grafici
│   ├── telegram_realip            # Telegram con detection FRP
│   ├── backup_and_deploy.sh       # Deploy automatico con backup
│   └── TESTING_GUIDE.md
│
├── script-tools/                  # Tool deployment e utility
│   ├── smart-deploy-hybrid.sh     # Deploy intelligente multi-host
│   ├── deploy-plain-agent*.sh     # Deploy agent CheckMK
│   ├── install-frpc*.sh           # Installazione FRP client
│   └── scan-nmap*.sh              # Scanner rete interattivo
│
├── Install/                       # Guide installazione CheckMK
│   └── install-cmk8/
│
├── deploy script/                 # Script deployment legacy
├── test script/                   # Script test e verifica
│
└── *.ps1                          # Script automazione PowerShell
    ├── backup-*.ps1               # Sistema backup automatico
    ├── setup-*.ps1                # Setup automazione e configurazione
    └── quick-*.ps1                # Utility quick-access
```

---

## 🛡️ Script di Check

### Windows

**Directory**: `script-check-windows/`

#### ⭐ Ransomware Detection
Script avanzato per rilevamento tempestivo attività ransomware su share di rete.

**Features**:
- 🔍 Detection multi-pattern (estensioni sospette, ransom note, velocità I/O)
- 🐤 Canary files monitoring
- ⏱️ Timeout protection per share lente/bloccate
- 🔄 Auto-update da GitHub
- 📊 Metriche dettagliate per share

**Files**:
- `check_ransomware_activity.ps1` - Script principale (737 righe)
- `rcheck_ransomware_activity.ps1` - Remote wrapper con auto-update
- `ransomware_config.json` - Configurazione
- `test_ransomware_detection.ps1` - Test suite completo

**Documentazione**: [README-Ransomware-Detection.md](script-check-windows/README-Ransomware-Detection.md)

**Quick Start**:
```powershell
# Deploy su Windows Server
Copy-Item check_ransomware_activity.ps1, ransomware_config.json `
    -Destination "C:\ProgramData\checkmk\agent\local\"

# Configurazione
notepad C:\ProgramData\checkmk\agent\local\ransomware_config.json

# Test manuale
.\check_ransomware_activity.ps1 -VerboseLog
```

---

### NethServer 7

**Directory**: `script-check-ns7/nopolling/`

Monitoraggio completo per NethServer 7 (CentOS 7 based).

#### Script Disponibili

| Script | Descrizione | Metriche |
|--------|-------------|----------|
| `check_cockpit_sessions.sh` | Sessioni attive Cockpit | Sessioni, warning/crit |
| `check_dovecot_sessions.sh` | Sessioni IMAP/POP3 | Connessioni attive |
| `check_dovecot_maxuserconn.sh` | Max conn per utente | Peak connections |
| `check_dovecot_status.sh` | Stato servizio Dovecot | Service status |
| `check_dovecot_vsz.sh` | Memoria VSZ Dovecot | MB utilizzati |
| `check_postfix_status.sh` | Stato servizio Postfix | Service status |
| `check_postfix_process.sh` | Processi Postfix attivi | Process count |
| `check_postfix_queue.sh` | Coda email | Messaggi in coda |
| `check_webtop_status.sh` | Stato Webtop5 | Service status |
| `check_webtop_maxmemory.sh` | Memoria massima Webtop | MB allocated |
| `check_webtop_https.sh` | Stato HTTPS Webtop | Certificate expiry |
| `check_ssh_root_logins.sh` | Login root SSH | Failed attempts |
| `check_ssh_root_sessions.sh` | Sessioni root attive | Active sessions |
| `check_ssh_failures.sh` | Tentativi SSH falliti | Failed count |
| `check-sos-ns7.sh` | Report sosreport NS7 | Report generation |
| `check-sosid-ns7.sh` | ID caso sosreport | Case tracking |
| `check-pkg-install.sh` | Pacchetti installati | Package count |

**Pattern**: Ogni script ha il suo remote wrapper `rcheck_*.sh` con auto-update da GitHub.

---

### NethServer 8

**Directory**: `script-check-ns8/nopolling/`

Monitoraggio per NethServer 8 (Podman/Container based).

#### Script Disponibili

| Script | Descrizione | Funzionalità |
|--------|-------------|--------------|
| `monitor_podman_events.sh` | Monitor eventi Podman real-time | Container start/stop/die |
| `check-sos.sh` | Generazione report SOS NS8 | Diagnostic report |
| `rmonitor_podman_events.sh` | Remote wrapper eventi Podman | Auto-update |
| `rcheck-sos.sh` | Remote wrapper SOS | Auto-update |

**Note**: NethServer 8 usa architettura container-based, gli script sono ottimizzati per Podman.

---

### Ubuntu/Linux

**Directory**: `script-check-ubuntu/`

Script check generici per distribuzioni Ubuntu/Debian.

**Note**: Directory pronta per nuovi script di monitoraggio Linux generico.

---

### Proxmox

**Directory**: `Proxmox/nopolling/`

Monitoraggio Proxmox Virtual Environment tramite API.

#### Script Disponibili

| Script | Descrizione | API Endpoint |
|--------|-------------|--------------|
| `check-proxmox-vm-status.sh` | Stato VM (running/stopped) | `/api2/json/nodes/*/qemu` |
| `check-proxmox-vm-snapshot-status.sh` | Stato snapshot VM | `/api2/json/nodes/*/qemu/*/snapshot` |
| `proxmox_vm_api.sh` | Test connessione API Proxmox | API authentication |
| `proxmox_vm_disks.sh` | Monitoraggio dischi VM | Disk usage |
| `proxmox_vm_monitor.sh` | Monitor generale VM | CPU, RAM, Disk |

**Remote Wrappers**: Prefisso `r` per ogni script (es. `rcheck-proxmox-vm-status.sh`)

**Requisiti**:
- Token API Proxmox configurato
- `curl` e `jq` installati
- Permessi lettura su API Proxmox

---

## 📧 Script di Notifica

**Directory**: `script-notify-checkmk/`

Sistema avanzato di notifiche CheckMK con supporto FRP (Fast Reverse Proxy).

### Features Principali

#### 🌐 Real IP Detection
Estrae IP reale anche dietro proxy FRP per notifiche accurate:
```python
# Detection automatica scenario
if 'NOTIFY_HOSTLABEL_real_ip' in os.environ:
    real_ip = os.environ['NOTIFY_HOSTLABEL_real_ip']
    # Usa real_ip invece di HOSTADDRESS
```

#### 📊 Grafici Integrati
Email HTML con grafici performance inclusi automaticamente:
- CPU usage
- Memory utilization  
- Disk I/O
- Network traffic

#### 🔔 Multi-Channel
- **Email**: `mail_realip*` - Varie versioni (HTML, hybrid, safe)
- **Telegram**: `telegram_realip` - Bot Telegram con formattazione

### Script Disponibili

| Script | Descrizione | Features |
|--------|-------------|----------|
| `mail_realip_hybrid` | Email HTML + Real IP + Grafici | ⭐ Consigliato |
| `mail_realip_hybrid_v24` | Versione CheckMK 2.4+ | Latest version |
| `mail_realip_hybrid_safe` | Versione con fallback | Extra safety |
| `mail_realip` | Email base Real IP | Minimal |
| `mail_realip_html` | Email HTML Real IP | No graphs |
| `telegram_realip` | Telegram Real IP | Bot integration |
| `backup_and_deploy.sh` | Deploy automatico con backup | 🔧 Tool |

### Deployment

```bash
# 1. Backup configurazione esistente
./backup_and_deploy.sh --backup-only

# 2. Test dry-run
./backup_and_deploy.sh --dry-run

# 3. Deploy effettivo
./backup_and_deploy.sh

# 4. Verifica
su - $(cat /etc/omd/site)
ls -la local/share/check_mk/notifications/
```

**Documentazione**: [TESTING_GUIDE.md](script-notify-checkmk/TESTING_GUIDE.md)

---

## 🚀 Tool di Deploy

**Directory**: `script-tools/`

Utility per deployment automatizzato CheckMK Agent e script.

### 🎯 Deploy Monitoring Scripts (NUOVO)

Script interattivo per deployment selettivo di monitoring scripts su host remoti.

**Features**:
- 🔍 Auto-detect sistema operativo (NS7/NS8/Proxmox/Ubuntu)
- 📋 Menu interattivo con lista script disponibili
- ✅ Deploy selettivo (singoli script o tutti)
- 🎯 Copia automatica in `/usr/lib/check_mk_agent/local/`
- 🔄 Usa repository locale `/opt/checkmk-tools`

**Installazione one-liner**:
```bash
# Download ed esecuzione diretta
curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/deploy-monitoring-scripts.sh -o /tmp/deploy.sh && bash /tmp/deploy.sh
```

**Uso manuale**:
```bash
# Se hai già il repository clonato
cd /opt/checkmk-tools
./script-tools/full/deploy-monitoring-scripts.sh
```

**Esempio output**:
```
========================================
  Deploy Monitoring Scripts
========================================

✅ Repository trovato: /opt/checkmk-tools
Sistema rilevato: NethServer 7

Script disponibili:
  1) rcheck_cockpit_sessions.sh
  2) rcheck_dovecot_status.sh
  3) rcheck_postfix_queue.sh
  [...]
  
Selezione (numeri separati da spazi, 'a' per tutti, 'q' per uscire): 1 3 5
```

---

### Smart Deploy Hybrid

Sistema intelligente per deployment multi-host con auto-update.

**Features**:
- 🔄 Auto-download da GitHub con cache
- 🛡️ Fallback su cache in caso di network issue
- ⏱️ Timeout protection (30s default)
- 📝 Logging dettagliato
- ✅ Validazione sintassi pre-deploy

**Files**:
- `smart-deploy-hybrid.sh` - Deploy intelligente
- `README-Smart-Deploy.md` - Documentazione base
- `README-Smart-Deploy-Enhanced.md` - Funzionalità avanzate

**Esempio**:
```bash
# Deploy script su host remoto
./smart-deploy-hybrid.sh \
    --host ns7-server.local \
    --scripts check_cockpit_sessions,check_dovecot_status \
    --github-repo Coverup20/checkmk-tools
```

### Deploy Agent CheckMK

Installazione e configurazione CheckMK Agent.

| Script | Descrizione |
|--------|-------------|
| `deploy-plain-agent.sh` | Deploy agent singolo host |
| `deploy-plain-agent-multi.sh` | Deploy multi-host da lista |
| `install-and-deploy-plain-agent.sh` | Install + deploy completo |

### Installazione FRP Client

| Script | Descrizione |
|--------|-------------|
| `install-frpc.sh` | Installazione FRP client base |
| `install-frpc2.sh` | Installazione FRP v2 |
| `install-frpc-dryrun.sh` | Test senza modifiche |

### Network Scanner

| Script | Descrizione |
|--------|-------------|
| `scan-nmap-interattivo-verbose.sh` | Scanner Nmap interattivo |
| `scan-nmap-interattivo-verbose-multi-options.sh` | Scanner con opzioni avanzate |

---

## ⚙️ Automazione e Backup

### Script PowerShell Root Directory

Sistema automatizzato per backup e sync del repository.

#### Backup Automatico

| Script | Descrizione | Frequenza |
|--------|-------------|-----------|
| `quick-backup.ps1` | Backup rapido modifiche | Hourly |
| `backup-sync.ps1` | Backup + sync remoti | Daily |
| `backup-sync-complete.ps1` | Backup completo + multi-remote | Weekly |
| `backup-existing-config.ps1` | Backup configurazioni | On-demand |

#### Setup Automazione

| Script | Descrizione |
|--------|-------------|
| `setup-automation.ps1` | Wizard setup task schedulati |
| `setup-backup-automation.ps1` | Setup backup automatico |
| `create_backup_task.ps1` | Creazione task Windows |
| `check_task.ps1` | Verifica task esistenti |

#### Configurazione Git

| Script | Descrizione |
|--------|-------------|
| `setup-additional-remotes.ps1` | Aggiungi remote repository |
| `fix-gitlab-credentials.ps1` | Fix credenziali GitLab |
| `git-credential-fix.ps1` | Fix credenziali Git generiche |

**Quick Start Automazione**:
```powershell
# 1. Setup backup automatico
.\setup-automation.ps1

# Scegli opzione:
# 1. Backup ogni ora (quick)
# 2. Backup giornaliero mattina (9:00)
# 3. Backup giornaliero sera (22:00)
# 4. Backup settimanale (Lunedì 8:00)

# 2. Verifica task creato
.\check_task.ps1

# 3. Test manuale
.\quick-backup.ps1
```

---

## 🔧 Installazione

### Requisiti Base

#### Windows
- PowerShell 5.1 o superiore
- CheckMK Agent Windows installato
- .NET Framework 4.5+

#### Linux
- Bash 4.0+
- CheckMK Agent installato
- `curl`, `jq` (per alcuni script)
- Python 3 (per script notifica)

### Installazione Script Check

#### Windows

```powershell
# 1. Clone repository
git clone https://github.com/Coverup20/checkmk-tools.git
cd checkmk-tools

# 2. Deploy script desiderato
$scriptPath = "script-check-windows\nopolling\ransomware_detection"
Copy-Item "$scriptPath\rcheck_ransomware_activity.ps1" `
    -Destination "C:\ProgramData\checkmk\agent\local\"

Copy-Item "$scriptPath\ransomware_config.json" `
    -Destination "C:\ProgramData\checkmk\agent\local\"

# 3. Test
& "C:\Program Files (x86)\checkmk\service\check_mk_agent.exe" test | 
    Select-String -Pattern "Ransomware"
```

#### Linux (NethServer / Ubuntu)

```bash
# 1. Clone repository
git clone https://github.com/Coverup20/checkmk-tools.git
cd checkmk-tools

# 2. Deploy con smart-deploy
cd script-tools
./smart-deploy-hybrid.sh \
    --local \
    --script ../script-check-ns7/nopolling/check_cockpit_sessions.sh

# Oppure copia manuale
sudo cp script-check-ns7/nopolling/rcheck_cockpit_sessions.sh \
    /usr/lib/check_mk_agent/local/

sudo chmod +x /usr/lib/check_mk_agent/local/rcheck_cockpit_sessions.sh

# 3. Test
check_mk_agent | grep -A5 "cockpit"
```

### Installazione Script Notifica

```bash
# Su server CheckMK (come root)
cd /tmp
git clone https://github.com/Coverup20/checkmk-tools.git
cd checkmk-tools/script-notify-checkmk

# Backup + Deploy automatico
./backup_and_deploy.sh

# Oppure manuale
omd stop
cp mail_realip_hybrid /omd/sites/SITENAME/local/share/check_mk/notifications/
chmod +x /omd/sites/SITENAME/local/share/check_mk/notifications/mail_realip_hybrid
omd start

# Configura in Web GUI
# Setup -> Notifications -> New Rule -> Notification Method: mail_realip_hybrid
```

---

## 📖 Documentazione

### README Specifici

Ogni categoria ha la sua documentazione dettagliata:

- 📂 **Windows**: [script-check-windows/README.md](script-check-windows/README.md)
  - 🛡️ **Ransomware**: [README-Ransomware-Detection.md](script-check-windows/README-Ransomware-Detection.md)

- 📂 **Notifiche**: [script-notify-checkmk/TESTING_GUIDE.md](script-notify-checkmk/TESTING_GUIDE.md)

- 📂 **Deploy Tools**: 
  - [script-tools/README-Smart-Deploy.md](script-tools/README-Smart-Deploy.md)
  - [script-tools/README-Smart-Deploy-Enhanced.md](script-tools/README-Smart-Deploy-Enhanced.md)

- 📂 **Soluzioni Complete**: [SOLUZIONE-COMPLETA.md](SOLUZIONE-COMPLETA.md)

### Guide Installazione

- 📦 **CheckMK 8**: [Install/install-cmk8/](Install/install-cmk8/)

### Configurazioni

- 🏷️ **Host Labels**: [checkmk-host-labels-config.md](checkmk-host-labels-config.md)

---

## 🧪 Testing

### Test Windows

```powershell
# Test singolo script
cd script-check-windows\nopolling\ransomware_detection
.\test_ransomware_detection.ps1 -TestScenario All

# Test manuale con debug
.\check_ransomware_activity.ps1 -VerboseLog

# Test via CheckMK Agent
& "C:\Program Files (x86)\checkmk\service\check_mk_agent.exe" test
```

### Test Linux

```bash
# Test singolo script
/usr/lib/check_mk_agent/local/check_cockpit_sessions

# Test output CheckMK
check_mk_agent | head -50

# Test con debug
bash -x /usr/lib/check_mk_agent/local/rcheck_cockpit_sessions.sh
```

### Test Notifiche

```bash
# Test detection FRP
cd script-notify-checkmk
python3 -c "
import os
os.environ['NOTIFY_HOSTLABEL_real_ip'] = '192.168.1.100'
os.environ['NOTIFY_HOSTADDRESS'] = '127.0.0.1:5000'
exec(open('mail_realip_hybrid').read())
"
```

---

## 🤝 Contributi

### Come Contribuire

1. **Fork** il repository
2. **Crea branch** per la tua feature: `git checkout -b feature/AmazingFeature`
3. **Commit** modifiche: `git commit -m 'Add AmazingFeature'`
4. **Push** al branch: `git push origin feature/AmazingFeature`
5. **Open Pull Request**

### Standard Codice

#### PowerShell
- Usa `CmdletBinding()` per script avanzati
- Parameter validation con `[Parameter()]`
- Help comments con `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`
- Error handling con `try/catch`
- Output CheckMK format: `<<<local>>>` + status lines

#### Bash
- Usa `#!/bin/bash` shebang
- Set `-euo pipefail` per error handling
- Funzioni con naming chiaro
- Commenti per logica complessa
- Output CheckMK format standard

#### Convenzioni Naming

**Files**:
- Check scripts: `check_<name>.{ps1|sh}`
- Remote wrappers: `rcheck_<name>.{ps1|sh}`
- Test scripts: `test_<name>.{ps1|sh}`
- Config files: `<name>_config.json`

**CheckMK Services**:
- Format: `<Category>_<Name>`
- Esempi: `Ransomware_Detection`, `Cockpit_Sessions`

**Metriche**:
- Snake case: `suspicious_files=10`
- Unit suffixes: `memory_mb=512`, `time_seconds=30`

---

## 📊 Statistiche Repository

### Script Count

| Categoria | Check Scripts | Remote Wrappers | Total |
|-----------|---------------|-----------------|-------|
| Windows | 1 | 1 | 2 |
| NethServer 7 | 17 | 17 | 34 |
| NethServer 8 | 2 | 2 | 4 |
| Proxmox | 5 | 5 | 10 |
| **Totale Check** | **25** | **25** | **50** |

| Categoria | Scripts | Descrizione |
|-----------|---------|-------------|
| Notifiche | 8 | Email + Telegram |
| Deploy Tools | 10+ | Smart deploy, agent install |
| Automazione | 15+ | Backup, setup, utility |
| Test | 5+ | Test suite e validazione |

### Lingue

- 🔷 **PowerShell**: ~40% (Windows scripts, automazione)
- 🟢 **Bash**: ~50% (Linux scripts, deploy)
- 🐍 **Python**: ~10% (Notifiche CheckMK)

---

## 🐛 Troubleshooting

### Windows

**Problema**: Script non appare in CheckMK
```powershell
# Verifica permessi
Get-Acl "C:\ProgramData\checkmk\agent\local\*.ps1"

# Verifica execution policy
Get-ExecutionPolicy

# Test manuale
& "C:\Program Files (x86)\checkmk\service\check_mk_agent.exe" test
```

**Problema**: Errore timeout share di rete
```powershell
# Check ransomware_config.json
# Aumenta timeout se necessario (default 30s)
```

### Linux

**Problema**: Script non eseguibile
```bash
sudo chmod +x /usr/lib/check_mk_agent/local/*.sh
```

**Problema**: Cache script non aggiorna
```bash
# Rimuovi cache manuale
rm -f /var/cache/checkmk-scripts/*
rm -f /tmp/*_cache.sh

# Forza re-download
/usr/lib/check_mk_agent/local/rcheck_script.sh
```

**Problema**: Script notifica non funziona
```bash
# Verifica permessi
ls -la /omd/sites/SITENAME/local/share/check_mk/notifications/

# Test manuale (come site user)
su - SITENAME
cd local/share/check_mk/notifications
python3 -c "exec(open('./mail_realip_hybrid').read())"
```

---

## 🔒 Sicurezza

### Best Practices

- ✅ Non committare credenziali in config files
- ✅ Usa variabili ambiente per token/password
- ✅ Limita permessi file (600 per config sensibili)
- ✅ Valida input utente
- ✅ Usa HTTPS per comunicazioni API
- ✅ Timeout per operazioni di rete
- ✅ Log eventi di sicurezza rilevanti

### Credenziali

File `.gitignore` include:
```
*.json
*.config
*.key
*.token
*_password.txt
```

Usare sempre:
```bash
# Linux
export API_TOKEN="your-token"

# Windows
$env:API_TOKEN = "your-token"
```

---

## 📞 Supporto

### Issue Reporting

Apri issue su GitHub con:
- 🖥️ Sistema operativo e versione
- 📦 Versione CheckMK
- 📄 Script coinvolto
- ❌ Messaggio errore completo
- 🔍 Log di debug (se disponibili)

### Community

- 💬 Discussions GitHub
- 📧 Email: coverup20@github.com

---

## 📄 License

MIT License - Vedi [LICENSE](LICENSE) per dettagli.

---

## ✨ Credits

Sviluppato con ❤️ per la community CheckMK.

### Autori Principali

- **Marzio** (@Coverup20) - Repository owner e maintainer

### Contributori

Grazie a tutti i contributori che hanno aiutato a migliorare questa collezione!

### Riconoscimenti

- [CheckMK](https://checkmk.com/) - Monitoring solution
- [NethServer](https://www.nethserver.org/) - Server platform
- CheckMK Community per patterns e best practices

---

## 🗺️ Roadmap

### In Sviluppo

- [ ] **Script Windows**:
  - [ ] check_windows_updates.ps1
  - [ ] check_iis_sites.ps1
  - [ ] check_active_directory.ps1

- [ ] **Script Linux**:
  - [ ] check_docker_containers.sh
  - [ ] check_systemd_failed.sh
  - [ ] check_cert_expiry.sh

- [ ] **Notifiche**:
  - [ ] Slack integration
  - [ ] Microsoft Teams webhook
  - [ ] Discord notifications

### Pianificato

- [ ] Web dashboard per monitoring
- [ ] Ansible playbooks per deployment
- [ ] Container images per test
- [ ] CI/CD pipeline per validation

---

## 📅 Changelog

### v1.5.0 (Current)
- ✅ Aggiunto ransomware detection per Windows
- ✅ Ridotto cache timeout wrapper (60s)
- ✅ Migliorato error handling script notifica
- ✅ Aggiornata documentazione completa

### v1.4.0
- ✅ Sistema smart deploy enhanced
- ✅ Pattern CheckMK ufficiali integrati
- ✅ Remote wrappers per tutti gli script

### v1.3.0
- ✅ Script notifica con Real IP + Grafici
- ✅ Backup automatico pre-deployment
- ✅ Testing guide completa

### v1.2.0
- ✅ Monitoraggio NethServer 8 (Podman)
- ✅ Script Proxmox VE
- ✅ Deploy tools automatizzati

### v1.1.0
- ✅ Collezione completa script NethServer 7
- ✅ Sistema backup automatico
- ✅ Setup automazione Windows

### v1.0.0
- ✅ Release iniziale
- ✅ Script base per CheckMK

---

**⭐ Se trovi utile questo repository, lascia una stella su GitHub!**

**🐛 Problemi? Apri una issue!**

**🤝 Vuoi contribuire? Le PR sono benvenute!**

---

*Ultimo aggiornamento: Ottobre 2025*

# 📚 Indice Repository CheckMK Tools

Repository organizzato per gestione CheckMK, integrazione Ydea, e script di monitoraggio.

## 🗂️ Struttura Directory

### 📂 **script-tools/** - Strumenti principali
Script per gestione, deployment e manutenzione CheckMK.

- **`remote/`** - Launcher remoti (r*.sh) - 7 righe, eseguono da GitHub
- **`full/`** - Script completi standalone
  - Git sync automatico (`auto-git-sync.sh`, `install-auto-git-sync.sh`)
  - Update & upgrade (`update-all-scripts.sh`, `upgrade-checkmk.sh`)
  - Deployment agenti (`deploy-plain-agent.sh`, `smart-deploy-hybrid.sh`)
  - Installation FRPC (`install-frpc.sh`, `install-frpc2.sh`)
  - CheckMK tuning (v3, v4, v5)
  - Network tools (nmap scan)

### 📂 **Ydea-Toolkit/** - Integrazione Ydea
Integrazione completa con sistema ticketing Ydea.

- **`remote/`** - Launcher Ydea (`rydea-toolkit.sh`, `rcreate-ticket-ita.sh`, etc.)
- **`full/`** - Script completi Ydea
  - Toolkit completo (`ydea-toolkit.sh`)
  - Monitoring integration (`ydea-monitoring-integration.sh`)
  - Health & ticket monitor
  - Template e utilità

### 📂 **script-notify-checkmk/** - Notifiche CheckMK
Script di notifica avanzati per CheckMK.

- **`remote/`** - Launcher notifiche (`rmail_realip`, `rtelegram_realip`, `rydea_realip`)
- **`full/`** - Script notifiche completi
  - `ydea_realip` - Crea ticket automatici su Ydea
  - `mail_realip` - Email con real IP resolution
  - `telegram_realip` - Notifiche Telegram
  - Documentazione (TESTING_GUIDE, CHANGELOG, FIX guides)

### 📂 **Fix/** - Script di fix e troubleshooting
Risoluzione problemi CheckMK e componenti.

- **`remote/`** - Launcher fix (`rfix-frp-checkmk-host.sh`, `rforce-update-checkmk.sh`)
- **`full/`** - Script fix completi
  - CheckMK fixes (`force-update-checkmk.sh`, `fix-frp-checkmk-host.sh`)
  - Windows fixes (PowerShell scripts)
  - Ransomware protection fixes
  - Git credentials fixes

### 📂 **script-check-{ns7,ns8,ubuntu,windows}/** - Script di check
Script di monitoring per diverse piattaforme.

- **`polling/`** - Check con polling attivo
- **`nopolling/`** - Check passivi/on-demand

### 📂 **Proxmox/** - Script Proxmox
Monitoring e gestione Proxmox VE.

- **`polling/`** - Check con polling
- **`nopolling/`** - Check passivi

### 📂 **Install/** - Installer e bootstrap
Script di installazione e bootstrap.

- **`checkmk-installer/`** - Installer CheckMK
- **`Agent-FRPC/`** - Installer agente + FRPC
- **`install-cmk8/`** - Installer CheckMK v8
- `bootstrap-installer.sh`, `make-bootstrap-iso.sh`

### 📂 **test script/** - Script di test
Script per testing e validazione.

### 📂 **deploy script/** - Script di deployment
Script per deploy automatico.

---

## 🚀 Quick Start

### Uso Script Remoti (Consigliato)

```bash
# Esegui launcher remoto direttamente da GitHub
curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/remote/rinstall-auto-git-sync.sh | bash

# Oppure scarica il launcher (7 righe) e eseguilo
wget https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/remote/rinstall-auto-git-sync.sh
chmod +x rinstall-auto-git-sync.sh
./rinstall-auto-git-sync.sh
```

### Uso Script Locali

```bash
# Clone repository
git clone https://github.com/Coverup20/checkmk-tools.git
cd checkmk-tools

# Esegui script completo
chmod +x script-tools/full/install-auto-git-sync.sh
sudo ./script-tools/full/install-auto-git-sync.sh
```

---

## 📖 Convenzioni

### Nomenclatura File
- **`r{nome}.sh`** - Launcher remoto (nella cartella `remote/`)
- **`{nome}.sh`** - Script completo (nella cartella `full/`)

### Struttura Launcher Remoto
```bash
#!/bin/bash
# Launcher per eseguire {NOME} remoto dal repo GitHub
SCRIPT_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/{path}/full/{nome}.sh"
bash <(curl -fsSL "$SCRIPT_URL") "$@"
```

### Vantaggi Launcher Remoti
1. **Portabilità**: 7 righe invece di 100+
2. **Aggiornamenti automatici**: Sempre ultima versione da GitHub
3. **Semplicità deployment**: Non serve git clone
4. **Manutenzione zero**: Aggiorna solo il file full/

---

## 🔗 Link Utili

- **GitHub**: https://github.com/Coverup20/checkmk-tools
- **GitLab**: https://gitlab.com/coverup20-group/checkmk-tools
- **Documentazione CheckMK**: https://docs.checkmk.com/

---

## 📝 File Documentazione

- `README.md` - Readme principale
- `DOCUMENTATION_INDEX.md` - Indice documentazione
- `PROJECT_STATUS.md` - Stato progetto
- `SESSION_COMPLETE.md` - Sessioni complete
- `COMPLETION_SUMMARY.md` - Riassunto completamenti
- Vari `*_SUMMARY.md`, `*_CHANGELOG.md` - Documenti specifici

---

## ⚙️ Automazioni Windows (PowerShell)

Script PowerShell per automazione Windows:
- `backup-sync-complete.ps1` - Backup e sync completo
- `setup-automation.ps1` - Setup automazione
- `setup-backup-automation.ps1` - Setup backup auto
- `quick-backup.ps1` - Backup veloce
- Vari fix script (`fix-*.ps1`)

---

**Autore**: Marzio Bordin  
**Supporto**: ChatGPT / GitHub Copilot  
**Licenza**: MIT (se non specificato diversamente)

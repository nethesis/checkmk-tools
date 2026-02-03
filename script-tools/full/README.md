# Script Completi (Full)

Questa cartella contiene gli **script completi** che vengono scaricati ed eseguiti dai launcher remoti.

## Caratteristiche

- **Codice completo**: Script standalone con tutte le funzionalità
- **Auto-contenuti**: Non dipendono da altri file
- **Eseguibili localmente**: Possono essere usati anche senza launcher
- **Versionati**: Tracciati da git per vedere la storia

## Script disponibili

### Gestione Repository
- `auto-git-sync.sh` - Sync automatico del repository
- `install-auto-git-sync.sh` - Installa servizio systemd per auto-sync
- `update-all-scripts.sh` - Aggiorna script esistenti dal repo
- `update-scripts-from-repo.sh` - Script updater originale

### CheckMK Management
- `upgrade-checkmk.sh` - Upgrade versione CheckMK
- `install-checkmk-log-optimizer.sh` - Ottimizzazione log CheckMK

### Deployment & Installation
- `install-agent-interactive.sh` - Installer agente interattivo
- `install-and-deploy-plain-agent.sh` - Install + deploy agente
- `deploy-plain-agent.sh` - Deploy agente plain
- `deploy-plain-agent-multi.sh` - Deploy multi-host

### FRPC Installation
- `install-frpc.sh` - Installer FRPC standard
- `install-frpc2.sh` - Installer FRPC v2
- `install-frpc-dryrun.sh` - Test FRPC senza installare
- `install-checkmk-agent-debtools-frp-nsec8c.sh` - Install completo NS8

### Network Tools
- `scan-nmap-interattivo-verbose.sh` - Scan nmap interattivo
- `scan-nmap-interattivo-verbose-multi-options.sh` - Scan avanzato

### Smart Deploy
- `smart-deploy-hybrid.sh` - Deploy ibrido intelligente
- `smart-wrapper-template.sh` - Template per wrapper
- `smart-wrapper-example.sh` - Esempio wrapper

### CheckMK Tuning
- `checkmk-tuning-interactive.sh` - Tuning interattivo
- `checkmk-tuning-interactive-v3.sh` - Versione 3
- `checkmk-tuning-interactive-v4.sh` - Versione 4
- `checkmk-tuning-interactive-v5.sh` - Versione 5 (latest)

## Uso Locale

```bash
# Clone del repository
git clone https://github.com/Coverup20/checkmk-tools.git
cd checkmk-tools/script-tools/full

# Esecuzione diretta
chmod +x auto-git-sync.sh
./auto-git-sync.sh 60
```

## Uso Remoto (Consigliato)

Usa i launcher nella cartella `../remote/` per eseguire sempre l'ultima versione:

```bash
# Scarica ed esegui il launcher
curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/remote/rauto-git-sync.sh | bash -s 60
```

---

🚀 **Launcher remoti**: Vedi cartella `../remote/`

# Script Remoti (Launcher)

Questa cartella contiene i **launcher remoti** (prefisso `r*`) che scaricano ed eseguono gli script completi da GitHub.

## Caratteristiche

- **Dimensione minima**: ~7 righe di codice per file
- **Esecuzione remota**: Usa `bash <(curl -fsSL URL)`
- **Sempre aggiornati**: Scaricano l'ultima versione da GitHub
- **Nessuna manutenzione locale**: Non richiedono aggiornamenti sul sistema

## Come funzionano

```bash
#!/bin/bash
# Launcher per eseguire SCRIPT remoto dal repo GitHub
SCRIPT_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/SCRIPT.sh"
bash <(curl -fsSL "$SCRIPT_URL") "$@"
```

## Uso

```bash
# Esegui direttamente il launcher
./rinstall-auto-git-sync.sh

# Oppure scaricalo ed eseguilo
curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/remote/rinstall-auto-git-sync.sh | bash
```

## Vantaggi

1. **Portabilità**: Copia 7 righe invece di centinaia
2. **Aggiornamenti automatici**: Usa sempre l'ultima versione
3. **Semplicità**: Non serve git clone o sync
4. **Affidabilità**: Se GitHub è raggiungibile, funziona

## Script disponibili

- `rauto-git-sync.sh` - Launcher per auto-git-sync
- `rinstall-auto-git-sync.sh` - Launcher per installer
- `rupdate-all-scripts.sh` - Launcher per updater
- `rupgrade-checkmk.sh` - Launcher per upgrade CheckMK
- E molti altri...

---

📁 **Script completi**: Vedi cartella `../full/`

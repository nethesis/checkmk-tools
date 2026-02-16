#!/usr/bin/env python3
"""
Remote launcher per auto-deploy-checks.py
Scarica e esegue la versione completa da repository
Default: --install-remote --yes (installa solo remote launchers automaticamente)
"""

import urllib.request
import sys

REPO_URL = "https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/auto-deploy-checks.py"

try:
    # Download script remoto
    with urllib.request.urlopen(REPO_URL, timeout=10) as response:
        script_code = response.read().decode('utf-8')
    
    # Aggiungi argomenti default se non specificati
    if len(sys.argv) == 1:
        # Nessun argomento → modalità automatica (solo remote launchers)
        sys.argv.extend(['--install-remote', '--yes'])
    
    # Esegui nel namespace globale (come se fosse lo script principale)
    exec(script_code, {'__name__': '__main__'})
    
except Exception as e:
    print(f"✗ Errore download/esecuzione script remoto: {e}")
    sys.exit(1)

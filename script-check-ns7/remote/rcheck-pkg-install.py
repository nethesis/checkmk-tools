#!/usr/bin/env python3
"""
Remote launcher per check-pkg-install.py
Scarica e esegue la versione Python completa da repository
"""

import urllib.request
import sys

REPO_URL = "https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-check-ns7/full/check-pkg-install.py"

try:
    # Download ed esegui lo script remoto
    with urllib.request.urlopen(REPO_URL, timeout=10) as response:
        script_code = response.read().decode('utf-8')
    
    # Esegui nel namespace globale
    exec(script_code, {'__name__': '__main__'})
    
except Exception as e:
    print(f"3 PKG_INSTALL - Failed to download/execute remote script: {e}")
    sys.exit(0)

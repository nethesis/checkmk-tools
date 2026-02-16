#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Remote launcher per check-pkg-install.py
Scarica e esegue la versione Python completa da repository
"""

import urllib.request
import sys
import os

# Forza encoding UTF-8 per gestire caratteri speciali nei log
os.environ['PYTHONIOENCODING'] = 'utf-8'

REPO_URL = "https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-check-ns7/full/check-pkg-install.py"

try:
    with urllib.request.urlopen(REPO_URL, timeout=10) as response:
        script_code = response.read().decode('utf-8')
    
    exec(script_code, {'__name__': '__main__'})
    
except Exception as e:
    print(f"3 Check-Pkg-Install - Failed to download/execute remote script: {e}")
    sys.exit(0)
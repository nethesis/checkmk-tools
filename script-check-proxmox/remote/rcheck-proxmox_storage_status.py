#!/usr/bin/env python3
"""
Remote launcher per check-proxmox_storage_status.py
"""

import urllib.request
import sys

REPO_URL = "https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-check-proxmox/full/check-proxmox_storage_status.py"

try:
    with urllib.request.urlopen(REPO_URL, timeout=10) as response:
        script_code = response.read().decode('utf-8')
    exec(script_code, {'__name__': '__main__'})
except Exception as e:
    print(f"3 PVE_Storage - Failed to download/execute: {e}")
    sys.exit(0)

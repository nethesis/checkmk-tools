#!/bin/bash
# Remote launcher per rcheck-sosid-ns7 - Wrapper bash con UTF-8 encoding
export PYTHONIOENCODING=utf-8
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

python3 - <<'PYTHON_SCRIPT'
import urllib.request
import sys

REPO_URL = "https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-check-ns7/full/rcheck-sosid-ns7.py"

try:
    with urllib.request.urlopen(REPO_URL, timeout=10) as response:
        script_code = response.read().decode('utf-8')
    
    exec(script_code, {'__name__': '__main__'})

except Exception as e:
    print(f"3 sosid_ns7 - Failed to download/execute: {e}")
    sys.exit(0)
PYTHON_SCRIPT

#!/usr/bin/env python3
"""
Remote launcher for install_agent_interactive.py
Downloads and executes the full Python script from GitHub repository
"""

import urllib.request
import sys

REPO_URL = "https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/install/Agent-FRPC/full/install_agent_interactive.py"

try:
    # Download and execute the remote script
    with urllib.request.urlopen(REPO_URL, timeout=10) as response:
        script_code = response.read().decode('utf-8')
    
    # Execute in global namespace (as if it were the main script)
    exec(script_code, {'__name__': '__main__'})
    
except Exception as e:
    print(f"ERROR: Failed to download/execute remote script: {e}", file=sys.stderr)
    sys.exit(1)

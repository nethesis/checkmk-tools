#!/usr/bin/env python3
"""
Python wrapper for check_dhcp_leases.sh
Version: 1.0.0
"""

import subprocess
import sys
from pathlib import Path

VERSION = "1.0.0"
SERVICE = "DHCP_Leases"
LEGACY_SCRIPT = Path("/opt/checkmk-tools/script-check-nsec8/full/check_dhcp_leases.sh")


def main() -> int:
    if not LEGACY_SCRIPT.exists():
        print(f"3 {SERVICE} - Legacy script missing: {LEGACY_SCRIPT}")
        return 0

    try:
        result = subprocess.run(
            [str(LEGACY_SCRIPT)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=30,
            check=False,
        )
    except Exception as error:
        print(f"3 {SERVICE} - Legacy wrapper error: {error}")
        return 0

    output = (result.stdout or "").strip()
    if output:
        print(output)
        return 0

    error_text = (result.stderr or f"legacy exit code {result.returncode}").strip()
    print(f"3 {SERVICE} - Legacy wrapper error: {error_text}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

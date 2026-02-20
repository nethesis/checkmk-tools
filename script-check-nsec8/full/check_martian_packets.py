#!/usr/bin/env python3
"""check_martian_packets.py - CheckMK local check martian packets (Python puro)."""

import re
import subprocess
import sys
from pathlib import Path

WARN_THRESHOLD = 10
CRIT_THRESHOLD = 50
LOG_FILE = Path("/var/log/messages")


def read_int(path: str) -> int:
    file_path = Path(path)
    if not file_path.exists():
        return 0
    value = file_path.read_text(encoding="utf-8", errors="ignore").strip()
    return int(value) if value.isdigit() else 0


def main() -> int:
    martian_count = 0
    martian_sources: list[str] = []
    martian_destinations: list[str] = []

    lines: list[str] = []
    if LOG_FILE.exists():
        lines.extend(LOG_FILE.read_text(encoding="utf-8", errors="ignore").splitlines()[-200:])

    dmesg = subprocess.run(["dmesg"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, check=False)
    if dmesg.returncode == 0:
        lines.extend(dmesg.stdout.splitlines())

    for line in lines:
        lower = line.lower()
        if "martian" not in lower:
            continue
        if "martian source" in lower:
            martian_count += 1
            match = re.search(r"from ((?:\d{1,3}\.){3}\d{1,3})", line)
            if match:
                martian_sources.append(match.group(1))
        if "martian destination" in lower:
            martian_count += 1
            match = re.search(r"to ((?:\d{1,3}\.){3}\d{1,3})", line)
            if match:
                martian_destinations.append(match.group(1))

    unique_ips = len(set(martian_sources + martian_destinations))
    rp_filter_all = read_int("/proc/sys/net/ipv4/conf/all/rp_filter")
    rp_filter_default = read_int("/proc/sys/net/ipv4/conf/default/rp_filter")

    if rp_filter_all == 1 or rp_filter_default == 1:
        rp_filter_status = "strict"
    elif rp_filter_all == 2 or rp_filter_default == 2:
        rp_filter_status = "loose"
    else:
        rp_filter_status = "disabled"

    if martian_count >= CRIT_THRESHOLD:
        status, status_text = 2, f"CRITICAL - {martian_count} martian packets rilevati"
    elif martian_count >= WARN_THRESHOLD:
        status, status_text = 1, f"WARNING - {martian_count} martian packets rilevati"
    elif martian_count > 0:
        status, status_text = 0, f"OK - {martian_count} martian packets (sotto soglia)"
    elif rp_filter_status == "disabled":
        status, status_text = 1, "WARNING - rp_filter disabilitato (nessun martian rilevato)"
    else:
        status, status_text = 0, f"OK - Nessun martian packet, rp_filter: {rp_filter_status}"

    print(
        f"{status} Martian_Packets count={martian_count};{WARN_THRESHOLD};{CRIT_THRESHOLD};0 unique_ips={unique_ips} "
        f"- {status_text} | martian_count={martian_count} unique_ips={unique_ips} rp_filter_all={rp_filter_all} rp_filter_default={rp_filter_default}"
    )

    if martian_sources:
        sample = " ".join(sorted(set(martian_sources))[:5])
        print(f"0 Martian_Sources - IPs: {sample}")
    if martian_destinations:
        sample = " ".join(sorted(set(martian_destinations))[:5])
        print(f"0 Martian_Destinations - IPs: {sample}")

    print(f"0 RP_Filter_Status - Mode: {rp_filter_status} (all={rp_filter_all}, default={rp_filter_default})")
    return 0


if __name__ == "__main__":
    sys.exit(main())

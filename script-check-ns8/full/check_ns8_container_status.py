#!/usr/bin/env python3
"""
check_ns8_container_status.py - Stato container NS8 per CheckMK

Version: 1.1.0
"""

import subprocess
import sys
from typing import List, Tuple

VERSION = "1.1.0"
SERVICE = "NS8_Container_Status"


def run_command(cmd: List[str], timeout: int = 30) -> Tuple[int, str, str]:
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            timeout=timeout,
        )
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except subprocess.TimeoutExpired:
        return 1, "", "timeout"
    except FileNotFoundError:
        return 127, "", "command not found"
    except Exception as exc:
        return 1, "", str(exc)


def get_instances() -> List[str]:
    code, out, _ = run_command(["runagent", "-l"])
    if code != 0 or not out:
        return []

    result = []
    for line in out.splitlines():
        name = line.strip()
        if not name or name in ("cluster", "node"):
            continue
        result.append(name)
    return result


def get_containers(instance: str) -> List[Tuple[str, str]]:
    code, out, _ = run_command(
        [
            "runagent",
            "-m",
            instance,
            "podman",
            "ps",
            "-a",
            "--format",
            "{{.Names}}|{{.Status}}",
        ]
    )
    if code != 0 or not out:
        return []

    rows: List[Tuple[str, str]] = []
    for line in out.splitlines():
        if "|" not in line:
            continue
        name, status = line.split("|", 1)
        rows.append((name.strip(), status.strip()))
    return rows


def is_instance_active(instance: str) -> bool:
    code, _, _ = run_command(["runagent", "-m", instance, "true"])
    return code == 0


def is_running(status: str) -> bool:
    return status.startswith("Up")


def main() -> int:
    if run_command(["which", "runagent"])[0] != 0:
        print(f"3 {SERVICE} - UNKNOWN: runagent non trovato")
        return 0

    instances = get_instances()
    if not instances:
        print(f"3 {SERVICE} - UNKNOWN: nessuna istanza NS8 trovata")
        return 0

    critical_problems: List[str] = []
    warning_notes: List[str] = []
    checked = 0

    for instance in instances:
        if not is_instance_active(instance):
            warning_notes.append(f"{instance}:instance-inactive")
            continue

        containers = get_containers(instance)
        if not containers:
            warning_notes.append(f"{instance}:no-containers")
            continue

        for container_name, container_status in containers:
            checked += 1
            if not is_running(container_status):
                critical_problems.append(f"{instance}:{container_name}({container_status})")

    if checked == 0:
        detail = ", ".join(warning_notes[:8]) if warning_notes else "nessun dato"
        print(f"1 {SERVICE} - WARNING: nessun container rilevato | {detail}")
        return 0

    if critical_problems:
        detail = ", ".join(critical_problems[:10])
        if len(critical_problems) > 10:
            detail = f"{detail}, ... (+{len(critical_problems) - 10} altri)"
        print(f"2 {SERVICE} - CRIT: problematici={len(critical_problems)}/{checked} | {detail}")
    elif warning_notes:
        detail = ", ".join(warning_notes[:10])
        if len(warning_notes) > 10:
            detail = f"{detail}, ... (+{len(warning_notes) - 10} altri)"
        print(f"1 {SERVICE} - WARNING: running={checked}, note={len(warning_notes)} | {detail}")
    else:
        print(f"0 {SERVICE} - OK: tutti i container sono running ({checked}/{checked})")

    return 0


if __name__ == "__main__":
    sys.exit(main())

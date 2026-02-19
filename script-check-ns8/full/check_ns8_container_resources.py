#!/usr/bin/env python3
"""
check_ns8_container_resources.py - Risorse container NS8 per CheckMK

Version: 1.0.0
"""

import re
import subprocess
import sys
from typing import List, Tuple

VERSION = "1.0.0"
CPU_WARN = 80.0
CPU_CRIT = 95.0
MEM_WARN = 80.0
MEM_CRIT = 95.0


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


def parse_percent(value: str) -> float:
    clean = value.replace("%", "").replace(",", ".").strip()
    try:
        return float(clean)
    except ValueError:
        return 0.0


def sanitize_service(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]", "_", value)


def get_stats(instance: str) -> List[Tuple[str, float, float, str]]:
    code, out, _ = run_command(
        [
            "runagent",
            "-m",
            instance,
            "podman",
            "stats",
            "--no-stream",
            "--format",
            "{{.Name}}|{{.CPUPerc}}|{{.MemPerc}}|{{.MemUsage}}",
        ]
    )
    if code != 0 or not out:
        return []

    result: List[Tuple[str, float, float, str]] = []
    for line in out.splitlines():
        parts = line.split("|", 3)
        if len(parts) != 4:
            continue
        name = parts[0].strip()
        cpu = parse_percent(parts[1])
        mem = parse_percent(parts[2])
        usage = parts[3].strip()
        result.append((name, cpu, mem, usage))
    return result


def state_for(cpu: float, mem: float) -> int:
    if cpu >= CPU_CRIT or mem >= MEM_CRIT:
        return 2
    if cpu >= CPU_WARN or mem >= MEM_WARN:
        return 1
    return 0


def label_for(state: int) -> str:
    if state == 2:
        return "CRIT"
    if state == 1:
        return "WARN"
    return "OK"


def main() -> int:
    if run_command(["which", "runagent"])[0] != 0:
        print("3 NS8_Container_Resources - UNKNOWN: runagent non trovato")
        return 0

    instances = get_instances()
    if not instances:
        print("3 NS8_Container_Resources - UNKNOWN: nessuna istanza NS8 trovata")
        return 0

    lines = 0
    for instance in instances:
        stats = get_stats(instance)
        for container_name, cpu, mem, usage in stats:
            lines += 1
            state = state_for(cpu, mem)
            label = label_for(state)
            service = sanitize_service(f"NS8_Res_{instance}_{container_name}")
            print(
                f"{state} {service} - {label}: cpu={cpu:.2f}% mem={mem:.2f}% usage={usage} | cpu={cpu:.2f};{CPU_WARN};{CPU_CRIT};0;100 mem={mem:.2f};{MEM_WARN};{MEM_CRIT};0;100"
            )

    if lines == 0:
        print("1 NS8_Container_Resources - WARNING: nessuna metrica container disponibile")

    return 0


if __name__ == "__main__":
    sys.exit(main())

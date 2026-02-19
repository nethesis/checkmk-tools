#!/usr/bin/env python3
"""
install-cmk-local-discovery-trigger.py

Installer systemd per cmk-local-discovery-trigger.py con guardrail di produzione.

Crea:
- /etc/systemd/system/checkmk-local-discovery-trigger.service
- /etc/systemd/system/checkmk-local-discovery-trigger.timer

Version: 1.1.0
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import List

VERSION = "1.1.0"
SYSTEMD_DIR = Path("/etc/systemd/system")
SERVICE_NAME = "checkmk-local-discovery-trigger.service"
TIMER_NAME = "checkmk-local-discovery-trigger.timer"
DEFAULT_SCRIPT = Path("/opt/checkmk-tools/script-tools/full/sync_update/cmk-local-discovery-trigger.py")


def run(cmd: List[str]) -> None:
    subprocess.run(cmd, check=True)


def require_root() -> None:
    if os.geteuid() != 0:
        print("[ERROR] Eseguire come root", file=sys.stderr)
        sys.exit(1)


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Installa service/timer guardrail per local discovery trigger")
    parser.add_argument("--site", default="monitoring", help="Nome site OMD")
    parser.add_argument("--run-as-user", default="monitoring", help="Utente systemd del servizio")
    parser.add_argument("--run-as-group", default="monitoring", help="Gruppo systemd del servizio")
    parser.add_argument("--script-path", default=str(DEFAULT_SCRIPT), help="Path script cmk-local-discovery-trigger.py")
    parser.add_argument("--agent-timeout", type=int, default=45, help="Timeout per host cmk -d in secondi")
    parser.add_argument("--detect-plugins", default="local", help="Plugin target per discovery (default: local)")
    parser.add_argument(
        "--no-activate",
        action="store_true",
        help="Non eseguire 'cmk -O' al termine (default: activate abilitato)",
    )
    parser.add_argument("--interval-min", type=int, default=10, help="Intervallo timer in minuti")
    parser.add_argument("--boot-delay-min", type=int, default=3, help="Delay run dopo boot in minuti")
    parser.add_argument("--timeout-start-min", type=int, default=25, help="TimeoutStartSec in minuti")
    parser.add_argument("--runtime-max-min", type=int, default=25, help="RuntimeMaxSec in minuti")
    parser.add_argument("--accuracy-sec", type=int, default=60, help="AccuracySec del timer")
    parser.add_argument("--hosts", default="", help="Lista host separati da virgola (vuoto = tutti gli host del site)")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    require_root()

    script_path = Path(args.script_path)
    if not script_path.exists():
        print(f"[ERROR] Script non trovato: {script_path}", file=sys.stderr)
        return 1

    exec_cmd = [
        "/usr/bin/python3",
        str(script_path),
        "--site",
        args.site,
        "--agent-timeout",
        str(args.agent_timeout),
        "--detect-plugins",
        args.detect_plugins,
    ]

    if not args.no_activate:
        exec_cmd.append("--activate")

    if args.hosts.strip():
        exec_cmd.extend(["--hosts", args.hosts.strip()])

    service_content = f"""[Unit]
Description=CheckMK local services change detector (discovery trigger)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User={args.run_as_user}
Group={args.run_as_group}
ExecStart={' '.join(exec_cmd)}
TimeoutStartSec={args.timeout_start_min}min
RuntimeMaxSec={args.runtime_max_min}min
NoNewPrivileges=true
"""

    timer_content = f"""[Unit]
Description=Run CheckMK local services change detector every {args.interval_min} minutes

[Timer]
OnBootSec={args.boot_delay_min}min
OnUnitActiveSec={args.interval_min}min
Persistent=true
AccuracySec={args.accuracy_sec}s

[Install]
WantedBy=timers.target
"""

    service_path = SYSTEMD_DIR / SERVICE_NAME
    timer_path = SYSTEMD_DIR / TIMER_NAME

    write_text(service_path, service_content)
    write_text(timer_path, timer_content)

    run(["systemctl", "daemon-reload"])
    run(["systemctl", "enable", "--now", TIMER_NAME])
    run(["systemctl", "restart", TIMER_NAME])
    run(["systemctl", "start", SERVICE_NAME])

    print(f"[OK] install-cmk-local-discovery-trigger.py v{VERSION}")
    print(f"[OK] Service: {service_path}")
    print(f"[OK] Timer:   {timer_path}")
    print(f"[OK] Verifica: systemctl status {SERVICE_NAME} --no-pager")
    print(f"[OK] Verifica: systemctl list-timers --all | grep {TIMER_NAME}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

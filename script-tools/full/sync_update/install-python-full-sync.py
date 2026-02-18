#!/usr/bin/env python3
"""
install-python-full-sync.py - Installer systemd per sync Python full checks

Crea:
- checkmk-python-full-sync.service (oneshot)
- checkmk-python-full-sync.timer (ogni 5 minuti)

Version: 1.0.0
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import List

VERSION = "1.0.0"
SYSTEMD_DIR = Path("/etc/systemd/system")
SERVICE_NAME = "checkmk-python-full-sync.service"
TIMER_NAME = "checkmk-python-full-sync.timer"
DEFAULT_SYNC_SCRIPT = Path("/opt/checkmk-tools/script-tools/full/sync_update/sync-python-full-checks.py")


def run(cmd: List[str]) -> None:
    subprocess.run(cmd, check=True)


def require_root() -> None:
    if os.geteuid() != 0:
        print("[ERROR] Eseguire come root", file=sys.stderr)
        sys.exit(1)


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


def ensure_python_executable(script_path: Path) -> None:
    if not script_path.exists():
        print(f"[ERROR] Script sync non trovato: {script_path}", file=sys.stderr)
        sys.exit(1)

    current_mode = script_path.stat().st_mode
    script_path.chmod(current_mode | 0o111)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Installa timer systemd per sync script Python full")
    parser.add_argument(
        "--sync-script",
        default=str(DEFAULT_SYNC_SCRIPT),
        help="Path script sync-python-full-checks.py",
    )
    parser.add_argument(
        "--repo",
        default="/opt/checkmk-tools",
        help="Path repository locale",
    )
    parser.add_argument(
        "--target",
        default="/usr/lib/check_mk_agent/local",
        help="Path local checks target",
    )
    parser.add_argument(
        "--category",
        default="auto",
        help="Categoria script-check-* o auto",
    )
    parser.add_argument(
        "--all-categories",
        action="store_true",
        help="Sincronizza tutte le categorie script-check-*",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    require_root()

    sync_script = Path(args.sync_script)
    ensure_python_executable(sync_script)

    py_bin = shutil.which("python3")
    if not py_bin:
        print("[ERROR] python3 non trovato nel PATH", file=sys.stderr)
        return 1

    cmd = [
        py_bin,
        str(sync_script),
        "--repo",
        args.repo,
        "--target",
        args.target,
    ]

    if args.all_categories:
        cmd.append("--all-categories")
    else:
        cmd.extend(["--category", args.category])

    service_content = f"""[Unit]
Description=CheckMK Python Full Checks Sync
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart={' '.join(cmd)}
"""

    timer_content = """[Unit]
Description=Run CheckMK Python Full Checks Sync every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
"""

    service_path = SYSTEMD_DIR / SERVICE_NAME
    timer_path = SYSTEMD_DIR / TIMER_NAME

    write_text(service_path, service_content)
    write_text(timer_path, timer_content)

    run(["systemctl", "daemon-reload"])
    run(["systemctl", "enable", "--now", TIMER_NAME])
    run(["systemctl", "start", SERVICE_NAME])

    print(f"[OK] install-python-full-sync.py v{VERSION}")
    print(f"[OK] Service: {service_path}")
    print(f"[OK] Timer:   {timer_path}")
    print(f"[OK] Verifica: systemctl status {TIMER_NAME} --no-pager")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
sync-python-full-checks.py - Sync automatico script Python CheckMK (full)

Rileva il tipo host, individua la categoria corretta nel repository locale
e copia/aggiorna tutti gli script Python da full/ verso la cartella local checks.

Version: 1.0.0
"""

import argparse
import os
import shutil
import stat
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple

VERSION = "1.0.0"
DEFAULT_REPO = Path("/opt/checkmk-tools")
DEFAULT_TARGET = Path("/usr/lib/check_mk_agent/local")


def log(message: str) -> None:
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [INFO] {message}")


def warn(message: str) -> None:
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [WARN] {message}")


def read_os_release() -> Dict[str, str]:
    result: Dict[str, str] = {}
    os_release = Path("/etc/os-release")
    if not os_release.exists():
        return result

    try:
        for line in os_release.read_text(encoding="utf-8", errors="ignore").splitlines():
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            result[key.strip()] = value.strip().strip('"')
    except OSError:
        return result

    return result


def detect_category() -> str:
    os_info = read_os_release()

    if Path("/etc/openwrt_release").exists():
        try:
            content = Path("/etc/openwrt_release").read_text(encoding="utf-8", errors="ignore").lower()
            if "nethsecurity" in content:
                return "script-check-nsec8"
        except OSError:
            pass
        return "script-check-nsec8"

    if Path("/etc/nethserver-release").exists():
        return "script-check-ns7"

    if Path("/usr/bin/runagent").exists() or Path("/usr/bin/api-cli").exists():
        return "script-check-ns8"

    if Path("/etc/pve").exists() and Path("/usr/bin/pvesh").exists():
        return "script-check-proxmox"

    os_id = os_info.get("ID", "").lower()
    if os_id in {"ubuntu", "debian"}:
        return "script-check-ubuntu"

    return "script-check-ubuntu"


def list_python_full_scripts(source_dir: Path) -> List[Path]:
    return sorted(
        [p for p in source_dir.glob("*.py") if p.is_file() and not p.name.startswith(".")]
    )


def ensure_executable(file_path: Path) -> None:
    current_mode = file_path.stat().st_mode
    file_path.chmod(current_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def sync_scripts(source_dir: Path, target_dir: Path) -> Tuple[int, int]:
    copied = 0
    unchanged = 0
    scripts = list_python_full_scripts(source_dir)

    if not scripts:
        warn(f"Nessuno script Python trovato in {source_dir}")
        return copied, unchanged

    target_dir.mkdir(parents=True, exist_ok=True)

    for src in scripts:
        dst = target_dir / src.name
        should_copy = (not dst.exists()) or (src.stat().st_mtime > dst.stat().st_mtime)

        if should_copy:
            shutil.copy2(src, dst)
            ensure_executable(dst)
            copied += 1
            log(f"Deploy: {src.name}")
        else:
            unchanged += 1

    return copied, unchanged


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sync automatico script Python CheckMK (full)"
    )
    parser.add_argument(
        "--repo",
        default=str(DEFAULT_REPO),
        help="Path repository locale (default: /opt/checkmk-tools)",
    )
    parser.add_argument(
        "--target",
        default=str(DEFAULT_TARGET),
        help="Path local checks target (default: /usr/lib/check_mk_agent/local)",
    )
    parser.add_argument(
        "--category",
        default="auto",
        help="Categoria script-check-* (default: auto)",
    )
    parser.add_argument(
        "--all-categories",
        action="store_true",
        help="Deploy da tutte le categorie script-check-*/full",
    )
    return parser.parse_args()


def collect_categories(repo_dir: Path, forced_category: str, all_categories: bool) -> List[str]:
    if all_categories:
        categories = sorted(
            [p.name for p in repo_dir.glob("script-check-*") if (p / "full").is_dir()]
        )
        return categories

    if forced_category != "auto":
        return [forced_category]

    return [detect_category()]


def main() -> int:
    args = parse_args()
    repo_dir = Path(args.repo)
    target_dir = Path(args.target)

    if os.geteuid() != 0:
        print("[ERROR] Eseguire come root", file=sys.stderr)
        return 1

    if not repo_dir.exists():
        print(f"[ERROR] Repository non trovato: {repo_dir}", file=sys.stderr)
        return 1

    categories = collect_categories(repo_dir, args.category, args.all_categories)
    if not categories:
        print("[ERROR] Nessuna categoria trovata", file=sys.stderr)
        return 1

    log(f"sync-python-full-checks.py v{VERSION}")
    log(f"Repository: {repo_dir}")
    log(f"Target: {target_dir}")
    log(f"Categorie: {', '.join(categories)}")

    total_copied = 0
    total_unchanged = 0
    categories_found = 0

    for category in categories:
        source_dir = repo_dir / category / "full"
        if not source_dir.is_dir():
            warn(f"Categoria non trovata o senza full/: {category}")
            continue

        categories_found += 1
        log(f"Sincronizzazione categoria: {category}")
        copied, unchanged = sync_scripts(source_dir, target_dir)
        total_copied += copied
        total_unchanged += unchanged

    if categories_found == 0:
        print("[ERROR] Nessuna categoria valida trovata nel repository", file=sys.stderr)
        return 1

    log(f"Completato: copied={total_copied}, unchanged={total_unchanged}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

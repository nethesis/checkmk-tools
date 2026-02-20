#!/usr/bin/env python3
"""
sync-python-full-checks.py - Sync automatico script Python CheckMK (full)

Rileva il tipo host, individua la categoria corretta nel repository locale
e copia/aggiorna tutti gli script Python da full/ verso la cartella local checks.

Version: 1.4.2
"""

import argparse
import hashlib
import os
import shutil
import stat
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Set, Tuple

VERSION = "1.4.2"
DEFAULT_REPO = Path("/opt/checkmk-tools")
DEFAULT_TARGET = Path("/usr/lib/check_mk_agent/local")


def log(message: str) -> None:
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [INFO] {message}")


def warn(message: str) -> None:
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [WARN] {message}")


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file_obj:
        while True:
            chunk = file_obj.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def extract_version(path: Path) -> str:
    try:
        content = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""

    for raw in content.splitlines():
        line = raw.strip()
        if not line.startswith("VERSION"):
            continue
        if "=" not in line:
            continue
        _, value = line.split("=", 1)
        return value.strip().strip('"').strip("'")
    return ""


def parse_semver(version: str) -> Tuple[int, int, int]:
    parts = [p.strip() for p in version.split(".") if p.strip()]
    if len(parts) != 3:
        raise ValueError("invalid semver")
    return int(parts[0]), int(parts[1]), int(parts[2])


def is_source_newer(src_version: str, dst_version: str) -> bool:
    if not src_version or not dst_version:
        return False
    try:
        return parse_semver(src_version) > parse_semver(dst_version)
    except ValueError:
        return False


def git_pull_repo(repo_dir: Path) -> None:
    git_dir = repo_dir / ".git"
    if not git_dir.exists():
        warn(f"Repository senza .git, skip git pull: {repo_dir}")
        return

    try:
        result = subprocess.run(
            ["git", "pull", "--ff-only"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True,
            timeout=60,
            check=False,
            cwd=str(repo_dir),
        )
    except (subprocess.SubprocessError, OSError) as exc:
        warn(f"git pull non eseguito: {exc}")
        return

    output = (result.stdout or "").strip()
    if result.returncode == 0:
        if output:
            log(f"git pull: {output.splitlines()[-1]}")
        else:
            log("git pull: OK")
    else:
        warn(f"git pull fallito (rc={result.returncode}): {output}")

        lower_output = output.lower()
        needs_autoheal = (
            "would be overwritten by merge" in lower_output
            or "please commit your changes or stash them" in lower_output
            or "your local changes" in lower_output
        )

        if not needs_autoheal:
            return

        warn("Auto-heal repo: tentativo stash modifiche locali + retry git pull")
        stash_msg = f"autoheal-sync-python-full-checks-{datetime.now().strftime('%Y%m%d-%H%M%S')}"

        stash_result = subprocess.run(
            ["git", "stash", "push", "--include-untracked", "-m", stash_msg],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True,
            timeout=60,
            check=False,
            cwd=str(repo_dir),
        )
        stash_output = (stash_result.stdout or "").strip()
        if stash_result.returncode == 0:
            if stash_output:
                log(f"git stash: {stash_output.splitlines()[-1]}")
            else:
                log("git stash: OK")
        else:
            warn(f"git stash fallito (rc={stash_result.returncode}): {stash_output}")

        retry = subprocess.run(
            ["git", "pull", "--ff-only"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True,
            timeout=60,
            check=False,
            cwd=str(repo_dir),
        )
        retry_output = (retry.stdout or "").strip()
        if retry.returncode == 0:
            if retry_output:
                log(f"git pull retry: {retry_output.splitlines()[-1]}")
            else:
                log("git pull retry: OK")
        else:
            warn(f"git pull retry fallito (rc={retry.returncode}): {retry_output}")


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

    if shutil.which("runagent") or shutil.which("api-cli"):
        return "script-check-ns8"

    if Path("/etc/pve").exists() and Path("/usr/bin/pvesh").exists():
        return "script-check-proxmox"

    if Path("/omd").exists() or Path("/opt/omd").exists():
        return "script-check-ubuntu"

    os_id = os_info.get("ID", "").lower()
    if os_id in {"ubuntu", "debian"}:
        return "script-check-ubuntu"

    return "script-check-ubuntu"


def list_python_full_scripts(source_dir: Path) -> List[Path]:
    def is_check_script(name: str) -> bool:
        return name.startswith("check_") or name.startswith("check-")

    return sorted(
        [
            p
            for p in source_dir.glob("*.py")
            if p.is_file() and not p.name.startswith(".") and is_check_script(p.name)
        ]
    )


def ensure_executable(file_path: Path) -> None:
    current_mode = file_path.stat().st_mode
    file_path.chmod(current_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def sync_scripts(source_dir: Path, target_dir: Path) -> Tuple[int, int, int]:
    copied = 0
    unchanged = 0
    skipped = 0
    scripts = list_python_full_scripts(source_dir)

    if not scripts:
        warn(f"Nessuno script Python trovato in {source_dir}")
        return copied, unchanged, skipped

    target_dir.mkdir(parents=True, exist_ok=True)

    for src in scripts:
        dst = target_dir / src.name
        should_copy = False
        src_hash = file_sha256(src)
        src_version = extract_version(src)
        if not dst.exists():
            should_copy = True
            log(f"Deploy new: {src.name}")
        else:
            dst_hash = file_sha256(dst)
            dst_version = extract_version(dst)

            hash_changed = src_hash != dst_hash
            version_changed = src_version != dst_version

            if not hash_changed and not version_changed:
                unchanged += 1
                continue

            should_copy = True
            reasons = []
            if version_changed:
                reasons.append(
                    f"version {dst_version or 'n/a'} -> {src_version or 'n/a'}"
                )
            if hash_changed:
                reasons.append("hash changed")
            reason_text = ", ".join(reasons) if reasons else "content changed"
            log(f"Overwrite changed: {src.name} ({reason_text})")

        if should_copy:
            shutil.copy2(src, dst)
            ensure_executable(dst)
            copied += 1
            log(f"Deploy: {src.name}")

    return copied, unchanged, skipped


def quarantine_extra_python_scripts(target_dir: Path, expected_names: Set[str]) -> int:
    if not target_dir.exists():
        return 0

    extras = [
        p
        for p in sorted(target_dir.glob("*.py"))
        if p.is_file() and not p.name.startswith(".") and p.name not in expected_names
    ]

    if not extras:
        return 0

    backup_dir = target_dir / (
        "cleanup_nonrepo_python_backup_" + datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    )
    backup_dir.mkdir(parents=True, exist_ok=True)

    moved = 0
    for extra in extras:
        destination = backup_dir / extra.name
        shutil.move(str(extra), str(destination))
        moved += 1
        log(f"Prune extra: {extra.name} -> {destination}")

    return moved


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

    git_pull_repo(repo_dir)

    total_copied = 0
    total_unchanged = 0
    total_pruned = 0
    total_skipped = 0
    categories_found = 0
    expected_names: Set[str] = set()

    for category in categories:
        source_dir = repo_dir / category / "full"
        if not source_dir.is_dir():
            warn(f"Categoria non trovata o senza full/: {category}")
            continue

        categories_found += 1
        log(f"Sincronizzazione categoria: {category}")
        expected_names.update([p.name for p in list_python_full_scripts(source_dir)])
        copied, unchanged, skipped = sync_scripts(source_dir, target_dir)
        total_copied += copied
        total_unchanged += unchanged
        total_skipped += skipped

    if categories_found == 0:
        print("[ERROR] Nessuna categoria valida trovata nel repository", file=sys.stderr)
        return 1

    total_pruned = quarantine_extra_python_scripts(target_dir, expected_names)

    log(
        f"Completato: copied={total_copied}, unchanged={total_unchanged}, skipped={total_skipped}, pruned={total_pruned}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

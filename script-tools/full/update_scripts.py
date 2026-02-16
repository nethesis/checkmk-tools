#!/usr/bin/env python3
"""
update_scripts.py - Update CheckMK Scripts from Repo

Aggiorna gli script installati nel sistema copiandoli dal repository locale.
Esegue git pull e sovrascrive solo i file esistenti nelle destinazioni note.

Destinazioni supportate:
- /opt/omd/sites/monitoring/local/bin
- /usr/lib/check_mk_agent/plugins
- /usr/lib/check_mk_agent/local
- /opt/ydea-toolkit

Usage:
    update_scripts.py [repo_dir]

Version: 1.0.0
"""

import sys
import os
import shutil
import subprocess
import glob
from pathlib import Path
from datetime import datetime
from typing import List, Optional

# --- Configurazione ---
DEFAULT_REPO_DIR = "/opt/checkmk-tools"
BACKUP_BASE = "/tmp/scripts-backup"

# Mappa Source (relativo a repo) -> Destination (assoluto)
MAPPINGS = [
    ("script-notify-checkmk", "/opt/omd/sites/monitoring/local/share/check_mk/notifications"),
    ("script-check-ns7", "/usr/lib/check_mk_agent/plugins"),
    ("script-check-ns7", "/usr/lib/check_mk_agent/local"),
    ("script-check-ns8", "/usr/lib/check_mk_agent/plugins"),
    ("script-check-ns8", "/usr/lib/check_mk_agent/local"),
    ("script-check-ubuntu", "/usr/lib/check_mk_agent/plugins"),
    ("script-check-ubuntu", "/usr/lib/check_mk_agent/local"),
    ("script-check-proxmox", "/usr/lib/check_mk_agent/plugins"),
    ("script-check-proxmox", "/usr/lib/check_mk_agent/local"),
    ("script-tools/full", "/opt/omd/sites/monitoring/local/bin"),
    ("Ydea-Toolkit", "/opt/ydea-toolkit"),
    # New Python scripts
    # ("script-tools/full/python", "/opt/omd/sites/monitoring/local/bin"), # Removed after move to root
]

class Console:
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    NC = '\033[0m'
    
    @staticmethod
    def log(msg): print(f"[INFO] {msg}")
    @staticmethod
    def warn(msg): print(f"{Console.YELLOW}[WARN] {msg}{Console.NC}")
    @staticmethod
    def error(msg): print(f"{Console.RED}[ERROR] {msg}{Console.NC}")
    @staticmethod
    def success(msg): print(f"{Console.GREEN}[OK] {msg}{Console.NC}")

def run_cmd(cmd, cwd=None):
    try:
        subprocess.run(cmd, cwd=cwd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        return True
    except subprocess.CalledProcessError:
        return False

def update_repo(repo_dir: Path):
    Console.log(f"Aggiorno repository: {repo_dir}")
    if not (repo_dir / ".git").exists():
        Console.error(f"Non è un repository git: {repo_dir}")
        sys.exit(1)
        
    # Stash local changes if any
    run_cmd(["git", "stash"], cwd=repo_dir)
    
    if run_cmd(["git", "pull", "--rebase", "origin", "main"], cwd=repo_dir):
        Console.success("Git pull completato")
    else:
        Console.warn("Git pull fallito (proseguo con versione locale)")

def resolve_src(repo_dir: Path, src_rel: str) -> Optional[Path]:
    p = repo_dir / src_rel
    if p.exists(): return p
    # Try with 'full' subdir if present? (Legacy logic)
    p_full = repo_dir / src_rel / "full"
    if p_full.exists(): return p_full
    return None

def update_files(repo_dir: Path, src_rel: str, dest_dir: str, backup_dir: Path):
    dest = Path(dest_dir)
    if not dest.exists():
        # Console.warn(f"Destinazione non trovata: {dest}")
        return 0

    src = resolve_src(repo_dir, src_rel)
    if not src:
        Console.warn(f"Sorgente non trovata nel repo: {src_rel}")
        return 0

    Console.log(f"Aggiorno {dest} da {src_rel}...")
    updated = 0
    
    # Iterate over files in DESTINATION
    # Logic: update only what is already installed
    for existing in dest.iterdir():
        if not existing.is_file() or existing.name.startswith("."):
            continue
            
        # Is it in source?
        source_file = src / existing.name
        if not source_file.exists():
            continue
            
        # Check content diff? Or just overwrite?
        # Script logic says overwrite.
        
        # Backup
        rel_path = existing.relative_to("/")
        backup_path = backup_dir / str(rel_path).replace(os.sep, "_")
        shutil.copy2(existing, backup_path)
        
        # Copy new content
        try:
            # Preserve owners/perms of destination
            stat = existing.stat()
            shutil.copy2(source_file, existing)
            os.chown(existing, stat.st_uid, stat.st_gid)
            os.chmod(existing, stat.st_mode)
            updated += 1
            print(f"  Updated: {existing.name}")
        except Exception as e:
            Console.error(f"Errore aggiornamento {existing.name}: {e}")

    # Also check if we should deploy NEW .py files if corresponding .sh exists?
    # Or simply: if source has .py corresponding to .sh in dest, maybe replace?
    # For now, simplistic approach from original bash script: iterate destination.
    
    return updated

def main():
    repo_dir_str = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPO_DIR
    repo_dir = Path(repo_dir_str)
    
    if not repo_dir.exists():
        Console.error(f"Repository path not found: {repo_dir}")
        sys.exit(1)
        
    backup_timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_dir = Path(BACKUP_BASE) / backup_timestamp
    backup_dir.mkdir(parents=True, exist_ok=True)
    
    update_repo(repo_dir)
    
    total_updated = 0
    for src, dest in MAPPINGS:
        total_updated += update_files(repo_dir, src, dest, backup_dir)
        
    Console.success(f"Totale file aggiornati: {total_updated}")
    Console.log(f"Backup salvato in: {backup_dir}")

if __name__ == "__main__":
    main()

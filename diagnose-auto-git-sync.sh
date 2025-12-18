#!/usr/bin/env bash
set -euo pipefail

# Script di diagnostica per verificare stato auto-git-sync

REPO_DIR="/opt/checkmk-tools"

echo "========================================="
echo "  Diagnostica Auto Git Sync"
echo "========================================="
echo

if command -v systemctl >/dev/null 2>&1; then
  if systemctl list-unit-files | grep -q '^auto-git-sync\.service'; then
    echo "OK: Servizio auto-git-sync.service trovato"
    echo
    echo "--- STATUS SERVIZIO ---"
    systemctl status auto-git-sync.service --no-pager || true
    echo
    echo "--- ULTIMI LOG ---"
    if command -v journalctl >/dev/null 2>&1; then
      journalctl -u auto-git-sync.service -n 50 --no-pager || true
    else
      echo "WARN: journalctl non disponibile"
    fi
    echo
  else
    echo "WARN: Servizio auto-git-sync.service NON trovato"
    echo
  fi
else
  echo "WARN: systemctl non disponibile"
  echo
fi

if [[ -d "$REPO_DIR" ]]; then
  echo "--- STATO REPOSITORY LOCALE ---"
  cd "$REPO_DIR"
  echo "Directory: $REPO_DIR"
  echo

  if command -v git >/dev/null 2>&1; then
    echo "Branch corrente: $(git branch --show-current 2>/dev/null || echo '<unknown>')"
    echo "Ultimo commit locale: $(git log -1 --oneline 2>/dev/null || echo '<unknown>')"
    git fetch origin 2>/dev/null || true
    echo "Ultimo commit remoto (origin/main): $(git log origin/main -1 --oneline 2>/dev/null || echo '<unknown>')"
    echo
    echo "Stato git:"
    git status || true
  else
    echo "WARN: git non disponibile"
  fi

  echo
  echo "Verifica struttura cartelle:"
  for p in \
    "script-tools/remote" "script-tools/full" \
    "Ydea-Toolkit/remote" "Ydea-Toolkit/full" \
    "Fix/remote" "Fix/full" \
    "script-notify-checkmk/remote" "script-notify-checkmk/full" \
    "script-check-ns7/polling" "script-check-ns7/nopolling" \
    "script-check-ns8/polling" "script-check-ns8/nopolling" \
    "script-check-ubuntu/polling" "script-check-ubuntu/nopolling" \
    "script-check-windows/polling" "script-check-windows/nopolling" \
    "Proxmox/polling" "Proxmox/nopolling"; do
    if [[ -e "$p" ]]; then
      ls -ld "$p" 2>/dev/null || true
    else
      echo "MISSING: $p"
    fi
  done
else
  echo "ERROR: Repository NON trovato in: $REPO_DIR" >&2
fi

echo
echo "========================================="
echo "  Fine Diagnostica"
echo "========================================="
